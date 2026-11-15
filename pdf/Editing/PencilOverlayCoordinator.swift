//
//  PencilOverlayCoordinator.swift
//  pdf
//
//  Created on 13/11/2026.
//

import PDFKit
import PencilKit
import UIKit

/// The four drawing tools exposed by the pen section, in the same spirit as
/// PencilKit's system tool picker.
enum PencilTool: String, CaseIterable, Identifiable {
    case pen
    case marker
    case pencil
    case eraser

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pen: "Penna"
        case .marker: "Evidenziatore"
        case .pencil: "Matita"
        case .eraser: "Gomma"
        }
    }

    var symbol: String {
        switch self {
        case .pen: "pencil.tip"
        case .marker: "highlighter"
        case .pencil: "pencil"
        case .eraser: "eraser.fill"
        }
    }

    func makeTool(color: UIColor, width: CGFloat) -> any PKTool {
        switch self {
        case .pen:
            PKInkingTool(.pen, color: color, width: width)
        case .marker:
            PKInkingTool(.marker, color: color, width: max(width * 4, 14))
        case .pencil:
            PKInkingTool(.pencil, color: color, width: width)
        case .eraser:
            PKEraserTool(.bitmap)
        }
    }
}

/// Gives PDFKit one PencilKit canvas per page. PDFKit handles positioning and
/// scaling of the overlay, so drawings stay aligned while scrolling and zooming.
final class PencilOverlayCoordinator: NSObject, PDFPageOverlayViewProvider, PKCanvasViewDelegate {
    var onDrawingChanged: (() -> Void)?

    var isMarkupEnabled = false {
        didSet { updateInteraction() }
    }

    var drawingTool: PencilTool = .pen {
        didSet { updateTools() }
    }

    var toolColor: UIColor = .black {
        didSet { updateTools() }
    }

    var toolWidth: CGFloat = 3 {
        didSet { updateTools() }
    }

    private let store: PencilDrawingStore
    private var drawings: [Int: PKDrawing]
    private var canvases: [Int: PencilCanvasView] = [:]
    private weak var pdfView: PDFView?
    private var lastEditedPageIndex: Int?
    private var isRestoringDrawing = false
    private var lastFlushDate = Date.distantPast

    init(store: PencilDrawingStore) {
        self.store = store
        self.drawings = store.loadAll()
        super.init()
    }

    func attach(_ view: PDFView) {
        pdfView = view
    }

    // MARK: - PDFPageOverlayViewProvider

    func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
        guard let pageIndex = pageIndex(for: page) else { return nil }

        let canvas = canvases[pageIndex] ?? makeCanvas(pageIndex: pageIndex)
        canvases[pageIndex] = canvas
        updateInteraction(for: canvas)

        isRestoringDrawing = true
        canvas.drawing = drawings[pageIndex] ?? PKDrawing()
        isRestoringDrawing = false

        return canvas
    }

    func pdfView(_ view: PDFView, willDisplayOverlayView overlayView: UIView, for page: PDFPage) {
        // PDFKit can reuse the page view and leave the canvas behind another
        // subview when a document is reopened in the same session.
        raiseOverlay(overlayView)
    }

    private func raiseOverlay(_ overlayView: UIView) {
        // Retry briefly: on the first display the overlay may not yet have a
        // superview when PDFKit finishes assigning it.
        for delay in [0.0, 0.1, 0.4] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak overlayView] in
                guard let overlayView, let superview = overlayView.superview else { return }
                superview.bringSubviewToFront(overlayView)
            }
        }
    }

    func pdfView(_ view: PDFView, willEndDisplayingOverlayView overlayView: UIView, for page: PDFPage) {
        guard let canvas = overlayView as? PencilCanvasView else { return }

        drawings[canvas.pageIndex] = canvas.drawing
        store.save(canvas.drawing, pageIndex: canvas.pageIndex)
        store.flush()
    }

    // MARK: - PKCanvasViewDelegate

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard !isRestoringDrawing,
              let canvas = canvasView as? PencilCanvasView else { return }

        drawings[canvas.pageIndex] = canvas.drawing
        store.save(canvas.drawing, pageIndex: canvas.pageIndex)
        lastEditedPageIndex = canvas.pageIndex
        onDrawingChanged?()

        // Throttle disk writes while the student is drawing quickly.
        if Date().timeIntervalSince(lastFlushDate) > 2 {
            store.flush()
            lastFlushDate = Date()
        }
    }

    // MARK: - Editing

    func canUndoLastStroke() -> Bool {
        guard let pageIndex = lastEditedPageIndex,
              let canvas = canvases[pageIndex] else { return false }
        return !canvas.drawing.strokes.isEmpty
    }

    @discardableResult
    func undoLastStroke() -> Bool {
        guard let pageIndex = lastEditedPageIndex,
              let canvas = canvases[pageIndex] else { return false }

        var drawing = canvas.drawing
        guard !drawing.strokes.isEmpty else { return false }

        drawing.strokes.removeLast()
        canvas.drawing = drawing
        drawings[pageIndex] = drawing
        store.save(drawing, pageIndex: pageIndex)
        onDrawingChanged?()
        return true
    }

    func persistAll() {
        for (pageIndex, canvas) in canvases {
            drawings[pageIndex] = canvas.drawing
            store.save(canvas.drawing, pageIndex: pageIndex)
        }
        store.flush()
    }

    // MARK: - Configuration

    private func makeCanvas(pageIndex: Int) -> PencilCanvasView {
        let canvas = PencilCanvasView()
        canvas.pageIndex = pageIndex
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = self
        canvas.tool = currentTool
        return canvas
    }

    private func updateInteraction() {
        for canvas in canvases.values {
            updateInteraction(for: canvas)
        }
    }

    private func updateInteraction(for canvas: PKCanvasView) {
        canvas.isUserInteractionEnabled = isMarkupEnabled
    }

    private func updateTools() {
        for canvas in canvases.values {
            canvas.tool = currentTool
        }
    }

    private var currentTool: any PKTool {
        drawingTool.makeTool(color: toolColor, width: toolWidth)
    }

    private func pageIndex(for page: PDFPage) -> Int? {
        guard let document = page.document else { return nil }
        let index = document.index(for: page)
        return index == NSNotFound ? nil : index
    }
}

/// Canvas that remembers which PDF page it belongs to.
final class PencilCanvasView: PKCanvasView {
    var pageIndex: Int = 0
}
