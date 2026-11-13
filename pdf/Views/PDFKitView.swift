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

    func makeUIView(context: Context) -> EditorPDFView {
        let view = EditorPDFView()
        view.backgroundColor = .secondarySystemBackground
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        view.document = controller.document

        controller.attach(view)
        view.overlay.onFinish = { [weak controller, weak view] points in
            guard let controller, let view else { return }
            controller.handleTouch(points: points, in: view)
        }

        return view
    }

    func updateUIView(_ view: EditorPDFView, context: Context) {
        controller.attach(view)

        view.overlay.isUserInteractionEnabled = controller.tool.capturesTouches
        view.overlay.showsPreview = controller.tool == .pen
        view.overlay.strokeColor = controller.activeColor
        view.overlay.lineWidth = controller.lineWidth

        if view.document !== controller.document {
            view.document = controller.document
        }
    }
}

/// PDFView with a transparent drawing layer pinned above its content.
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

/// Captures pencil/finger strokes and forwards them to the editor.
final class DrawingOverlayView: UIView {
    var onFinish: (([CGPoint]) -> Void)?

    var strokeColor: UIColor = .label {
        didSet { strokeLayer.strokeColor = strokeColor.cgColor }
    }

    var lineWidth: CGFloat = 3 {
        didSet { strokeLayer.lineWidth = lineWidth }
    }

    var showsPreview = true {
        didSet { strokeLayer.isHidden = !showsPreview }
    }

    private var points: [CGPoint] = []
    private let strokeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isMultipleTouchEnabled = false

        strokeLayer.fillColor = UIColor.clear.cgColor
        strokeLayer.strokeColor = strokeColor.cgColor
        strokeLayer.lineWidth = lineWidth
        strokeLayer.lineCap = .round
        strokeLayer.lineJoin = .round
        layer.addSublayer(strokeLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        strokeLayer.frame = bounds
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isUserInteractionEnabled, let point = touches.first?.location(in: self) else { return }
        points = [point]
        updatePreview()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isUserInteractionEnabled, let point = touches.first?.location(in: self) else { return }
        points.append(point)
        updatePreview()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isUserInteractionEnabled else { return }

        if let point = touches.first?.location(in: self), points.count <= 1 {
            // A tap still needs two points to produce a tiny ink dot.
            points.append(CGPoint(x: point.x + 0.1, y: point.y + 0.1))
        }

        onFinish?(points)
        reset()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        reset()
    }

    private func updatePreview() {
        guard showsPreview, let first = points.first else {
            strokeLayer.path = nil
            return
        }

        let path = UIBezierPath()
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        strokeLayer.path = path.cgPath
    }

    private func reset() {
        points.removeAll()
        strokeLayer.path = nil
    }
}
