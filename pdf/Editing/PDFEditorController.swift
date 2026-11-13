//
//  PDFEditorController.swift
//  pdf
//
//  Created on 13/11/2026.
//

import Foundation
import Observation
import PDFKit
import UIKit

enum AnnotationTool: String, CaseIterable, Identifiable {
    case select
    case highlight
    case underline
    case pen
    case erase
    case note

    var id: String { rawValue }

    var label: String {
        switch self {
        case .select: "Seleziona testo"
        case .highlight: "Evidenzia"
        case .underline: "Sottolinea"
        case .pen: "Scrivi a mano"
        case .erase: "Cancella annotazione"
        case .note: "Aggiungi nota"
        }
    }

    var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .highlight: "highlighter"
        case .underline: "underline"
        case .pen: "pencil.tip"
        case .erase: "eraser"
        case .note: "note.text"
        }
    }

    /// Tools that need to intercept touches before PDFView handles them.
    var capturesTouches: Bool {
        self == .pen || self == .erase || self == .note
    }

    var usesColor: Bool {
        self == .highlight || self == .underline || self == .pen
    }
}

struct PendingNote: Identifiable {
    let id = UUID()
    let page: PDFPage
    let point: CGPoint
}

/// Bridges SwiftUI with PDFKit while keeping track of annotations and undo state.
@Observable
final class PDFEditorController {
    let url: URL
    let document: PDFDocument

    var tool: AnnotationTool = .select
    var isDirty = false
    var pendingNote: PendingNote?

    private(set) var undoCount = 0
    private(set) var highlightColorIndex = 0
    private(set) var inkColorIndex = 0
    let lineWidth: CGFloat = 3

    let highlightPalette: [UIColor] = [.systemYellow, .systemGreen, .systemPink, .systemBlue, .systemOrange]
    let inkPalette: [UIColor] = [.label, .systemRed, .systemBlue, .systemGreen, .systemPurple]

    private weak var pdfView: PDFView?
    private var undoStack: [(page: PDFPage, annotation: PDFAnnotation)] = []

    init(url: URL) throws {
        guard let document = PDFDocument(url: url) else {
            throw PDFEditorError.unreadable(url)
        }
        self.url = url
        self.document = document
    }

    // MARK: - Derived state

    var canUndo: Bool { undoCount > 0 }
    var activePalette: [UIColor] { tool == .pen ? inkPalette : highlightPalette }
    var activeColorIndex: Int { tool == .pen ? inkColorIndex : highlightColorIndex }
    var activeColor: UIColor { activePalette[min(max(activeColorIndex, 0), activePalette.count - 1)] }
    var showsColorPicker: Bool { tool.usesColor }

    func attach(_ view: PDFView) {
        pdfView = view
    }

    func selectColor(at index: Int) {
        guard activePalette.indices.contains(index) else { return }
        if tool == .pen {
            inkColorIndex = index
        } else {
            highlightColorIndex = index
        }
    }

    // MARK: - Text markup

    func applyMarkup(_ type: PDFAnnotationSubtype) {
        guard let pdfView, let selection = pdfView.currentSelection else { return }

        let lines = selection.selectionsByLine()
        guard !lines.isEmpty else { return }

        for line in lines {
            for page in line.pages {
                let bounds = line.bounds(for: page).insetBy(dx: -1, dy: -2)
                guard bounds.width > 2, bounds.height > 2 else { continue }

                let annotation = PDFAnnotation(bounds: bounds, forType: type, withProperties: nil)
                annotation.color = type == .highlight
                    ? activeColor.withAlphaComponent(0.45)
                    : activeColor
                annotation.userName = "FratmPDF"
                annotation.modificationDate = Date()

                page.addAnnotation(annotation)
                registerUndo(page: page, annotation: annotation)
            }
        }

        isDirty = true
        pdfView.clearSelection()
    }

    // MARK: - Freehand ink

    func addInkStroke(_ viewPoints: [CGPoint], in view: PDFView) {
        guard let firstViewPoint = viewPoints.first,
              let page = view.page(for: firstViewPoint, nearest: true) else { return }

        let pagePoints = viewPoints.map { view.convert($0, to: page) }
        guard let firstPagePoint = pagePoints.first else { return }

        let path = UIBezierPath()
        path.move(to: firstPagePoint)

        if pagePoints.count == 1 {
            path.addLine(to: CGPoint(x: firstPagePoint.x + 0.1, y: firstPagePoint.y + 0.1))
        } else {
            for point in pagePoints.dropFirst() {
                path.addLine(to: point)
            }
        }

        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let expanded = path.bounds.insetBy(dx: -lineWidth * 2, dy: -lineWidth * 2)
        let bounds = CGRect(
            x: expanded.minX,
            y: expanded.minY,
            width: max(expanded.width, lineWidth * 2),
            height: max(expanded.height, lineWidth * 2)
        )

        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        let border = PDFBorder()
        border.lineWidth = lineWidth
        annotation.border = border
        annotation.color = activeColor
        annotation.userName = "FratmPDF"
        annotation.modificationDate = Date()
        annotation.add(path)

        page.addAnnotation(annotation)
        registerUndo(page: page, annotation: annotation)
        isDirty = true
    }

    // MARK: - Erase

    func eraseAnnotation(at viewPoint: CGPoint, in view: PDFView) {
        guard let page = view.page(for: viewPoint, nearest: true) else { return }
        let pagePoint = view.convert(viewPoint, to: page)

        guard let annotation = page.annotation(at: pagePoint) else { return }

        page.removeAnnotation(annotation)
        undoStack.removeAll { $0.annotation === annotation }
        undoCount = undoStack.count
        isDirty = true
    }

    // MARK: - Notes

    func beginNote(at viewPoint: CGPoint, in view: PDFView) {
        guard let page = view.page(for: viewPoint, nearest: true) else { return }
        pendingNote = PendingNote(page: page, point: view.convert(viewPoint, to: page))
    }

    func cancelNote() {
        pendingNote = nil
    }

    func commitNote(_ text: String) {
        guard let pending = pendingNote else { return }
        pendingNote = nil

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let fontSize: CGFloat = 12
        let width: CGFloat = 170
        let font = UIFont.systemFont(ofSize: fontSize, weight: .regular)

        let measured = (trimmed as NSString).boundingRect(
            with: CGSize(width: width - 12, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).size

        let height = max(measured.height + 16, 30)
        let bounds = CGRect(x: pending.point.x, y: pending.point.y, width: width, height: height)

        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = trimmed
        annotation.font = font
        annotation.fontColor = .label
        annotation.color = UIColor.systemYellow.withAlphaComponent(0.22)
        annotation.alignment = .left
        annotation.border = PDFBorder()
        annotation.border?.lineWidth = 1
        annotation.userName = "FratmPDF"
        annotation.modificationDate = Date()

        pending.page.addAnnotation(annotation)
        registerUndo(page: pending.page, annotation: annotation)
        isDirty = true
    }

    // MARK: - Touch routing

    func handleTouch(points: [CGPoint], in view: PDFView) {
        guard let lastPoint = points.last else { return }

        switch tool {
        case .pen:
            addInkStroke(points, in: view)
        case .erase:
            eraseAnnotation(at: lastPoint, in: view)
        case .note:
            beginNote(at: lastPoint, in: view)
        case .select, .highlight, .underline:
            break
        }
    }

    // MARK: - Undo / save

    func undo() {
        guard let last = undoStack.popLast() else { return }
        last.page.removeAnnotation(last.annotation)
        undoCount = undoStack.count
        isDirty = true
    }

    @discardableResult
    func save() -> Bool {
        guard isDirty else { return true }
        let saved = document.write(to: url)
        if saved { isDirty = false }
        return saved
    }

    private func registerUndo(page: PDFPage, annotation: PDFAnnotation) {
        undoStack.append((page, annotation))
        undoCount = undoStack.count
    }
}

enum PDFEditorError: LocalizedError {
    case unreadable(URL)

    var errorDescription: String? {
        switch self {
        case .unreadable(let url):
            "Non riesco ad aprire “\(url.lastPathComponent)”."
        }
    }
}
