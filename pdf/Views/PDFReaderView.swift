//
//  PDFReaderView.swift
//  pdf
//
//  Created on 13/11/2026.
//

import PDFKit
import SwiftUI
import UIKit

/// The questions are attached to the sheet item so the first presentation
/// always receives the generated quiz.
private struct QuizLaunch: Identifiable {
    let id = UUID()
    let questions: [StudyQuestion]
    let documentTitle: String
}

struct PDFReaderView: View {
    let item: LibraryDocument

    @Environment(TeacherStore.self) private var teacherStore
    @Environment(ReviewStore.self) private var reviewStore

    @State private var controller: PDFEditorController?
    @State private var quizLaunch: QuizLaunch?
    @State private var isPreparingQuiz = false
    @State private var isNoteAlertPresented = false
    @State private var noteText = ""
    @State private var loadError: String?

    @Namespace private var glassNamespace

    var body: some View {
        Group {
            if let controller {
                PDFKitView(controller: controller)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        annotationBar(for: controller)
                    }
                    .navigationTitle(item.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        readerToolbar(for: controller)
                    }
                    .onChange(of: controller.pendingNote?.id) { _, newValue in
                        guard newValue != nil else { return }
                        noteText = ""
                        isNoteAlertPresented = true
                    }
                    .onChange(of: controller.editingNote?.id) { _, newValue in
                        guard newValue != nil, let editing = controller.editingNote else { return }
                        noteText = editing.annotation.contents ?? ""
                        isNoteAlertPresented = true
                    }
                    .onDisappear {
                        controller.save()
                    }
                    .overlay {
                        if isPreparingQuiz {
                            ZStack {
                                Color.black.opacity(0.08)
                                    .ignoresSafeArea()

                                ProgressView("Il Teacher sta preparando le domande…")
                                    .padding(24)
                                    .background(
                                        .regularMaterial,
                                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    )
                            }
                            .transition(.opacity)
                        }
                    }
                    .sheet(item: $quizLaunch) { launch in
                        StudySessionView(
                            questions: launch.questions,
                            teacher: teacherStore.profile,
                            documentTitle: launch.documentTitle,
                            onAnswered: { question, correct in
                                if !correct {
                                    reviewStore.recordMiss(
                                        question: question,
                                        documentTitle: launch.documentTitle
                                    )
                                }
                            }
                        )
                    }
                    .alert("Nota sul PDF", isPresented: $isNoteAlertPresented) {
                        TextField("Scrivi la tua nota", text: $noteText, axis: .vertical)
                            .lineLimit(2...6)

                        if controller.editingNote != nil {
                            Button("Elimina", role: .destructive) {
                                controller.deleteEditingNote()
                                noteText = ""
                            }
                            Button("Annulla", role: .cancel) {
                                controller.cancelNoteEdit()
                                noteText = ""
                            }
                            Button("Salva") {
                                controller.saveEditingNote(noteText)
                                noteText = ""
                            }
                        } else {
                            Button("Annulla", role: .cancel) {
                                controller.cancelNote()
                                noteText = ""
                            }
                            Button("Aggiungi") {
                                controller.commitNote(noteText)
                                noteText = ""
                            }
                        }
                    } message: {
                        Text(
                            controller.editingNote != nil
                                ? "Modifica il testo, elimina la nota oppure trascinala sulla pagina per spostarla."
                                : "La nota sarà aggiunta al punto che hai toccato. Potrai trascinarla per spostarla."
                        )
                    }
            } else if let loadError {
                ContentUnavailableView(
                    "Impossibile aprire il PDF",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                ProgressView("Apro il PDF…")
            }
        }
        .task {
            loadDocumentIfNeeded()
        }
        .background(ReaderGestureLock())
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func readerToolbar(for controller: PDFEditorController) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                startQuiz(for: controller)
            } label: {
                TeacherAvatarView(profile: teacherStore.profile, size: 28)
            }
            .disabled(isPreparingQuiz)
            .accessibilityLabel("InterrogaMI")

            Button {
                controller.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!controller.canUndo)
            .accessibilityLabel("Annulla ultima azione")

            Button {
                controller.save()
            } label: {
                Image(systemName: controller.isDirty ? "square.and.arrow.down.fill" : "checkmark.circle")
            }
            .accessibilityLabel("Salva PDF")
        }
    }

    // MARK: - Annotation bar

    private func annotationBar(for controller: PDFEditorController) -> some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                if controller.tool == .pen {
                    drawingOptionsBar(for: controller)
                        .glassEffect(.regular.tint(Color.accentColor.opacity(0.06)), in: Capsule())
                        .glassEffectID("options", in: glassNamespace)
                        .glassEffectTransition(.matchedGeometry)
                }

                toolsBar(for: controller)
                    .glassEffect(.regular.tint(Color.accentColor.opacity(0.06)), in: Capsule())
                    .glassEffectID("tools", in: glassNamespace)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func toolsBar(for controller: PDFEditorController) -> some View {
        HStack(spacing: 2) {
            ForEach(AnnotationTool.allCases) { tool in
                toolButton(tool, controller: controller)
            }
        }
        .padding(6)
    }

    @ViewBuilder
    private func toolButton(_ tool: AnnotationTool, controller: PDFEditorController) -> some View {
        let isSelected = controller.tool == tool

        let button = Button {
            controller.tool = tool
        } label: {
            Image(systemName: tool.symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 34, height: 34)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.label)
        .accessibilityHint(accessibilityHint(for: tool))

        if isSelected {
            button.glassEffect(
                .regular.tint(Color.accentColor.opacity(0.65)).interactive(),
                in: Circle()
            )
        } else {
            button
        }
    }

    /// Unified pen/highlighter/pencil/eraser picker, with the color palette
    /// underneath. It replaces the separate drawing tools in the main bar.
    private func drawingOptionsBar(for controller: PDFEditorController) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(PencilTool.allCases) { drawingTool in
                    drawingToolButton(drawingTool, controller: controller)
                }
            }

            if controller.showsColorPicker {
                colorOptionsRow(for: controller)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func colorOptionsRow(for controller: PDFEditorController) -> some View {
        HStack(spacing: 10) {
            ForEach(Array(controller.activePalette.enumerated()), id: \.offset) { index, color in
                Button {
                    controller.selectColor(at: index)
                } label: {
                    Circle()
                        .fill(Color(uiColor: color))
                        .frame(width: 18, height: 18)
                        .padding(3)
                        .overlay(
                            Circle().strokeBorder(
                                Color.primary.opacity(controller.activeColorIndex == index ? 0.75 : 0.10),
                                lineWidth: controller.activeColorIndex == index ? 2 : 1
                            )
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Colore \(index + 1)")
                .accessibilityAddTraits(
                    controller.activeColorIndex == index ? .isSelected : []
                )
            }
        }
    }

    private func drawingToolButton(
        _ drawingTool: PencilTool,
        controller: PDFEditorController
    ) -> some View {
        let isSelected = controller.pencilTool == drawingTool

        return Button {
            controller.pencilTool = drawingTool
        } label: {
            Image(systemName: drawingTool.symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 34, height: 30)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(
                    isSelected ? Color.accentColor : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(drawingTool.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accessibilityHint(for tool: AnnotationTool) -> String {
        switch tool {
        case .select:
            "Seleziona il testo del PDF"
        case .pen:
            "Scegli penna, evidenziatore, matita o gomma"
        case .note:
            "Tocca la pagina per aggiungere una nota, tocca una nota per modificarla o trascinala per spostarla"
        }
    }

    // MARK: - Actions

    private func loadDocumentIfNeeded() {
        guard controller == nil, loadError == nil else { return }
        do {
            controller = try PDFEditorController(url: item.url)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func startQuiz(for controller: PDFEditorController) {
        guard !isPreparingQuiz else { return }
        isPreparingQuiz = true

        let document = controller.document
        let title = item.title

        Task { @MainActor in
            // Let SwiftUI render the progress overlay before reading the PDF.
            await Task.yield()

            // PDFKit is not thread-safe, so page text is read on the main
            // actor. The heavier text analysis runs in a detached task below.
            let pageTexts = extractPageTexts(from: document)
            let documentText = makeQuizText(from: pageTexts)
            // The model only sees the first 20 pages, so it must not be allowed
            // to reference a page outside that excerpt.
            let aiPageCount = min(document.pageCount, 20)

            var questions: [StudyQuestion] = []

            if #available(iOS 26.0, *), FoundationModelsQuizGenerator.isAvailable {
                questions = await FoundationModelsQuizGenerator.makeQuestions(
                    fromText: documentText,
                    pageCount: aiPageCount
                )
            }

            // Use the heuristic generator only when the model didn't return
            // enough valid questions, and keep whichever source produced more.
            if questions.count < 4 {
                let heuristicQuestions = await Task.detached(priority: .userInitiated) {
                    StudyQuestionGenerator.makeQuestions(from: pageTexts)
                }.value

                if heuristicQuestions.count > questions.count {
                    questions = heuristicQuestions
                }
            }

            isPreparingQuiz = false
            quizLaunch = QuizLaunch(questions: questions, documentTitle: title)
        }
    }

    private func extractPageTexts(
        from document: PDFDocument,
        maxPages: Int = 40
    ) -> [StudyPageText] {
        var pages: [StudyPageText] = []

        for pageIndex in 0..<min(document.pageCount, maxPages) {
            guard let page = document.page(at: pageIndex) else { continue }
            pages.append(
                StudyPageText(number: pageIndex + 1, text: page.string ?? "")
            )
        }

        return pages
    }

    /// Builds the text sent to Foundation Models. Only the first 20 pages are
    /// included, with an explicit page marker for each one.
    private func makeQuizText(
        from pages: [StudyPageText],
        maxCharacters: Int = 6000
    ) -> String {
        var parts: [String] = []
        var totalCharacters = 0

        for page in pages.prefix(20) {
            guard !page.text.isEmpty else { continue }
            let part = "[Pagina \(page.number)] \(page.text)"
            parts.append(part)
            totalCharacters += part.count
            if totalCharacters >= maxCharacters { break }
        }

        return String(parts.joined(separator: "\n").prefix(maxCharacters))
    }
}

/// Disables the NavigationStack's interactive pop gesture while the reader is
/// on screen. Otherwise a horizontal drag used to select text or annotate can
/// dismiss the reader instead of reaching PDFKit. The back button still works.
private struct ReaderGestureLock: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func loadView() {
            let view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
            self.view = view
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}
