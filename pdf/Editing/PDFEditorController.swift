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
    case pen
    case note

    var id: String { rawValue }

    var label: String {
        switch self {
        case .select: "Seleziona testo"
        case .pen: "Disegna"
        case .note: "Note"
        }
    }

    var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .pen: "pencil.tip"
        case .note: "note.text"
        }
    }

    /// Tools handled by the transparent overlay above PDFView.
    var capturesTouches: Bool {
        self == .note
    }

    /// Tools handled by the per-page PencilKit canvas.
    var usesPencilCanvas: Bool {
        self == .pen
    }
}

struct PendingNote: Identifiable {
    let id = UUID()
    let page: PDFPage
    let point: CGPoint
}

/// A note that is already on the page and can be edited, moved or deleted.
struct EditableNote: Identifiable {
    let id = UUID()
    let page: PDFPage
    let annotation: PDFAnnotation
}

/// Bridges SwiftUI with PDFKit while keeping track of annotations and undo state.
@Observable
final class PDFEditorController {
    let url: URL
    let document: PDFDocument
    let pencilCoordinator: PencilOverlayCoordinator

    var tool: AnnotationTool = .select

    /// Selected tool inside the unified drawing picker (pen/marker/pencil/eraser).
    var pencilTool: PencilTool = .pen
    var isDirty = false
    var pendingNote: PendingNote?
    var editingNote: EditableNote?

    private static let noteWidth: CGFloat = 170
    private static let noteFont = UIFont.systemFont(ofSize: 12, weight: .regular)

    private enum UndoAction {
        case removeAnnotation(page: PDFPage, annotation: PDFAnnotation)
        case addAnnotation(page: PDFPage, annotation: PDFAnnotation)
        case restoreNote(
            page: PDFPage,
            annotation: PDFAnnotation,
            contents: String?,
            bounds: CGRect
        )
    }

    private struct NoteDrag {
        let page: PDFPage
        let annotation: PDFAnnotation
        let startPoint: CGPoint
        let originalBounds: CGRect
    }

    private(set) var undoCount = 0
    private(set) var inkColorIndex = 0
    // The marker starts on yellow, like a classic highlighter; pen and pencil
    // keep their own color so switching tools doesn't change the ink.
    private(set) var markerColorIndex = 5
    private(set) var pencilRevision = 0
    let lineWidth: CGFloat = 3

    // The PDF page is always white, so ink must not use dynamic colors:
    // `.label` becomes white in dark mode and would be invisible.
    let inkPalette: [UIColor] = [.black, .systemRed, .systemBlue, .systemGreen, .systemPurple, .systemYellow]

    private var undoStack: [UndoAction] = []
    private var noteDrag: NoteDrag?

    init(url: URL) throws {
        guard let document = PDFDocument(url: url) else {
            throw PDFEditorError.unreadable(url)
        }
        self.url = url
        self.document = document
        self.pencilCoordinator = PencilOverlayCoordinator(
            store: PencilDrawingStore(documentURL: url)
        )
        pencilCoordinator.onDrawingChanged = { [weak self] in
            guard let self else { return }
            self.pencilRevision += 1
            self.isDirty = true
        }
    }

    // MARK: - Derived state

    var canUndo: Bool {
        if tool == .pen {
            _ = pencilRevision
            return pencilCoordinator.canUndoLastStroke()
        }
        return undoCount > 0
    }

    var activePalette: [UIColor] { inkPalette }
    var activeColorIndex: Int {
        pencilTool == .marker ? markerColorIndex : inkColorIndex
    }
    var activeColor: UIColor {
        inkPalette[min(max(activeColorIndex, 0), inkPalette.count - 1)]
    }
    var showsColorPicker: Bool { pencilTool != .eraser }

    func attach(_ view: PDFView) {
        pencilCoordinator.attach(view)
    }

    func selectColor(at index: Int) {
        guard inkPalette.indices.contains(index) else { return }

        if pencilTool == .marker {
            markerColorIndex = index
        } else {
            inkColorIndex = index
        }
    }

    // MARK: - Notes

    /// Handles a tap on the page while the note tool is active. Tapping an
    /// existing note opens it for editing; tapping empty space creates a new one.
    func handleTap(at viewPoint: CGPoint, in view: PDFView) {
        guard tool == .note else { return }

        if beginEditingNote(at: viewPoint, in: view) { return }
        beginNote(at: viewPoint, in: view)
    }

    func beginNote(at viewPoint: CGPoint, in view: PDFView) {
        guard let page = view.page(for: viewPoint, nearest: true) else { return }
        editingNote = nil
        pendingNote = PendingNote(page: page, point: view.convert(viewPoint, to: page))
    }

    func cancelNote() {
        pendingNote = nil
    }

    func commitNote(_ text: String) {
        guard let pending = pendingNote else { return }
        pendingNote = nil
        editingNote = nil

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let annotation = makeNote(text: trimmed, origin: pending.point)
        pending.page.addAnnotation(annotation)
        registerUndo(.removeAnnotation(page: pending.page, annotation: annotation))
        isDirty = true
    }

    func cancelNoteEdit() {
        editingNote = nil
    }

    /// Saves edits to an existing note. Clearing the text deletes the note.
    func saveEditingNote(_ text: String) {
        guard let editing = editingNote else { return }
        editingNote = nil
        pendingNote = nil

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            removeNote(editing)
            return
        }

        let annotation = editing.annotation
        let oldContents = annotation.contents
        let oldBounds = annotation.bounds

        let width = max(annotation.bounds.width, Self.noteWidth)
        let height = noteHeight(for: trimmed, width: width)
        let pageBounds = editing.page.bounds(for: .mediaBox)
        let maxTop = pageBounds.maxY
        let top = min(annotation.bounds.maxY, maxTop)
        let originY = max(top - height, pageBounds.minY)

        annotation.contents = trimmed
        annotation.bounds = CGRect(
            x: annotation.bounds.minX,
            y: originY,
            width: width,
            height: height
        )
        annotation.modificationDate = Date()
        refresh(annotation, on: editing.page)

        registerUndo(
            .restoreNote(
                page: editing.page,
                annotation: annotation,
                contents: oldContents,
                bounds: oldBounds
            )
        )
        isDirty = true
    }

    func deleteEditingNote() {
        guard let editing = editingNote else { return }
        editingNote = nil
        pendingNote = nil
        removeNote(editing)
    }

    private func beginEditingNote(at viewPoint: CGPoint, in view: PDFView) -> Bool {
        guard let hit = note(at: viewPoint, in: view) else { return false }
        pendingNote = nil
        editingNote = EditableNote(page: hit.page, annotation: hit.annotation)
        return true
    }

    private func removeNote(_ editing: EditableNote) {
        editing.page.removeAnnotation(editing.annotation)
        registerUndo(.addAnnotation(page: editing.page, annotation: editing.annotation))
        isDirty = true
    }

    // MARK: - Moving notes

    func beginNoteDrag(at viewPoint: CGPoint, in view: PDFView) {
        guard tool == .note, let hit = note(at: viewPoint, in: view) else { return }
        editingNote = nil
        pendingNote = nil
        noteDrag = NoteDrag(
            page: hit.page,
            annotation: hit.annotation,
            startPoint: viewPoint,
            originalBounds: hit.annotation.bounds
        )
    }

    func updateNoteDrag(at viewPoint: CGPoint, in view: PDFView) {
        guard let drag = noteDrag else { return }

        let start = view.convert(drag.startPoint, to: drag.page)
        let current = view.convert(viewPoint, to: drag.page)
        var bounds = drag.originalBounds.offsetBy(
            dx: current.x - start.x,
            dy: current.y - start.y
        )

        // Never let a note be dragged completely outside the page.
        let pageBounds = drag.page.bounds(for: .mediaBox)
        bounds.origin.x = min(
            max(bounds.origin.x, pageBounds.minX),
            max(pageBounds.minX, pageBounds.maxX - bounds.width)
        )
        bounds.origin.y = min(
            max(bounds.origin.y, pageBounds.minY),
            max(pageBounds.minY, pageBounds.maxY - bounds.height)
        )

        guard bounds != drag.annotation.bounds else { return }
        drag.annotation.bounds = bounds
        refresh(drag.annotation, on: drag.page)
    }

    func endNoteDrag(at viewPoint: CGPoint, in view: PDFView) {
        guard let drag = noteDrag else { return }
        updateNoteDrag(at: viewPoint, in: view)
        noteDrag = nil

        guard drag.annotation.bounds != drag.originalBounds else { return }

        registerUndo(
            .restoreNote(
                page: drag.page,
                annotation: drag.annotation,
                contents: drag.annotation.contents,
                bounds: drag.originalBounds
            )
        )
        isDirty = true
    }

    // MARK: - Note helpers

    private func note(
        at viewPoint: CGPoint,
        in view: PDFView
    ) -> (page: PDFPage, annotation: PDFAnnotation)? {
        guard let page = view.page(for: viewPoint, nearest: true) else { return nil }
        let pagePoint = view.convert(viewPoint, to: page)

        let annotation = page.annotations.last { candidate in
            isNote(candidate)
                && candidate.bounds.insetBy(dx: -4, dy: -4).contains(pagePoint)
        }
        guard let annotation else { return nil }
        return (page, annotation)
    }

    private func isNote(_ annotation: PDFAnnotation) -> Bool {
        annotation.userName == "FratmPDF" && annotation.type == "FreeText"
    }

    private func makeNote(text: String, origin: CGPoint) -> PDFAnnotation {
        let width = Self.noteWidth
        let height = noteHeight(for: text, width: width)
        let bounds = CGRect(x: origin.x, y: origin.y, width: width, height: height)

        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.font = Self.noteFont
        // PDF pages are white in both appearances, so use a fixed dark color
        // instead of the dynamic `.label` which is white in dark mode.
        annotation.fontColor = UIColor(white: 0.1, alpha: 1)
        annotation.color = UIColor.systemYellow.withAlphaComponent(0.22)
        annotation.alignment = .left
        annotation.border = PDFBorder()
        annotation.border?.lineWidth = 1
        annotation.userName = "FratmPDF"
        annotation.modificationDate = Date()
        return annotation
    }

    private func noteHeight(for text: String, width: CGFloat) -> CGFloat {
        let measured = (text as NSString).boundingRect(
            with: CGSize(width: width - 12, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: Self.noteFont],
            context: nil
        ).size
        return max(measured.height + 16, 30)
    }

    private func refresh(_ annotation: PDFAnnotation, on page: PDFPage) {
        // PDFKit does not always redraw when only the annotation model changes;
        // re-adding it forces the page to pick up the new bounds/contents.
        page.removeAnnotation(annotation)
        page.addAnnotation(annotation)
    }

    // MARK: - Undo / save

    func undo() {
        if tool == .pen {
            pencilCoordinator.undoLastStroke()
            return
        }

        guard let last = undoStack.popLast() else { return }

        switch last {
        case .removeAnnotation(let page, let annotation):
            page.removeAnnotation(annotation)
        case .addAnnotation(let page, let annotation):
            page.addAnnotation(annotation)
        case .restoreNote(let page, let annotation, let contents, let bounds):
            annotation.contents = contents
            annotation.bounds = bounds
            annotation.modificationDate = Date()
            refresh(annotation, on: page)
        }

        undoCount = undoStack.count
        isDirty = true
    }

    @discardableResult
    func save() -> Bool {
        pencilCoordinator.persistAll()

        guard isDirty else { return true }
        let saved = document.write(to: url)
        if saved { isDirty = false }
        return saved
    }

    private func registerUndo(_ action: UndoAction) {
        undoStack.append(action)
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
