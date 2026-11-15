//
//  PDFKitView.swift
//  pdf
//
//  Created on 13/11/2026.
//

import PDFKit
import SwiftUI
import UIKit

struct PDFKitView: UIViewRepresentable {
    let controller: PDFEditorController

    final class Coordinator {
        var wasInMarkupMode = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> EditorPDFView {
        let view = EditorPDFView()
        view.backgroundColor = .secondarySystemBackground
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.usePageViewController(false)
        view.autoScales = true
        // PDFKit asks for page overlays only if the provider is installed
        // before the document is assigned.
        view.pageOverlayViewProvider = controller.pencilCoordinator
        view.document = controller.document

        controller.attach(view)
        view.overlay.onTap = { [weak controller, weak view] point in
            guard let controller, let view else { return }
            controller.handleTap(at: point, in: view)
        }
        view.overlay.onDragBegan = { [weak controller, weak view] point in
            guard let controller, let view else { return }
            controller.beginNoteDrag(at: point, in: view)
        }
        view.overlay.onDragChanged = { [weak controller, weak view] point in
            guard let controller, let view else { return }
            controller.updateNoteDrag(at: point, in: view)
        }
        view.overlay.onDragEnded = { [weak controller, weak view] point in
            guard let controller, let view else { return }
            controller.endNoteDrag(at: point, in: view)
        }

        return view
    }

    func updateUIView(_ view: EditorPDFView, context: Context) {
        controller.attach(view)

        let coordinator = controller.pencilCoordinator
        coordinator.toolColor = controller.activeColor
        coordinator.toolWidth = controller.lineWidth
        coordinator.drawingTool = controller.pencilTool
        coordinator.isMarkupEnabled = controller.tool.usesPencilCanvas

        let wantsMarkup = controller.tool.usesPencilCanvas
        if context.coordinator.wasInMarkupMode != wantsMarkup {
            view.isInMarkupMode = wantsMarkup
            view.layoutDocumentView()
            context.coordinator.wasInMarkupMode = wantsMarkup
        }

        view.overlay.isUserInteractionEnabled = controller.tool.capturesTouches

        if view.document !== controller.document {
            view.document = controller.document
        }
    }
}

/// PDFView with a transparent layer that owns the eraser and note gestures.
/// Using recognizers (instead of raw touches) keeps the drag alive even when
/// PDFKit or the navigation stack would otherwise cancel the touches.
final class EditorPDFView: PDFView {
    let overlay = DrawingOverlayView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        overlay.frame = bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(overlay)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        overlay.frame = bounds
        bringSubviewToFront(overlay)
    }
}

/// Captures taps and drags for the eraser and note tools with dedicated
/// recognizers. Raw `touchesBegan/Moved/Ended` can be cancelled by the scroll
/// view or the navigation stack, which made horizontal eraser drags fail.
final class DrawingOverlayView: UIView {
    var onTap: ((CGPoint) -> Void)?
    var onDragBegan: ((CGPoint) -> Void)?
    var onDragChanged: ((CGPoint) -> Void)?
    var onDragEnded: ((CGPoint) -> Void)?

    private var points: [CGPoint] = []
    private var initialPoint: CGPoint?

    private lazy var panGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        gesture.maximumNumberOfTouches = 1
        gesture.cancelsTouchesInView = true
        return gesture
    }()

    private lazy var tapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        gesture.cancelsTouchesInView = true
        gesture.require(toFail: panGesture)
        return gesture
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isMultipleTouchEnabled = false
        addGestureRecognizer(panGesture)
        addGestureRecognizer(tapGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The pan gesture only begins after a small movement; remembering the
    /// original touch-down point lets the controller hit-test the note where
    /// the finger actually landed.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        initialPoint = touches.first?.location(in: self)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: self)

        switch gesture.state {
        case .began:
            let start = initialPoint ?? point
            points = [start, point]
            onDragBegan?(start)
            if start != point {
                onDragChanged?(point)
            }
        case .changed:
            points.append(point)
            onDragChanged?(point)
        case .ended:
            if points.count > 1 {
                onDragEnded?(point)
            } else {
                onTap?(point)
            }
            reset()
        case .cancelled, .failed:
            if points.count > 1 {
                onDragEnded?(point)
            }
            reset()
        default:
            break
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        initialPoint = nil
        onTap?(gesture.location(in: self))
    }

    private func reset() {
        points.removeAll()
        initialPoint = nil
    }
}
