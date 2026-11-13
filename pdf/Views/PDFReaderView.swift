//
//  PDFReaderView.swift
//  pdf
//
//  Created on 13/11/2026.
//

import PDFKit
import SwiftUI

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

    @State private var controller: PDFEditorController?
    @State private var quizLaunch: QuizLaunch?
    @State private var isNoteAlertPresented = false
    @State private var noteText = ""
    @State private var loadError: String?

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
                    .onDisappear {
                        controller.save()
                    }
                    .sheet(item: $quizLaunch) { launch in
                        StudySessionView(
                            questions: launch.questions,
                            teacher: teacherStore.profile,
                            documentTitle: launch.documentTitle
                        )
                    }
                    .alert("Nota sul PDF", isPresented: $isNoteAlertPresented) {
                        TextField("Scrivi la tua nota", text: $noteText)
                        Button("Annulla", role: .cancel) {
                            controller.cancelNote()
                        }
                        Button("Aggiungi") {
                            controller.commitNote(noteText)
                            noteText = ""
                        }
                    } message: {
                        Text("La nota sarà aggiunta al punto che hai toccato.")
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
            .accessibilityLabel("InterrogaMI")

            Button {
                controller.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!controller.canUndo)
            .accessibilityLabel("Annulla ultima annotazione")

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
        VStack(spacing: 10) {
            if controller.showsColorPicker {
                HStack(spacing: 12) {
                    ForEach(Array(controller.activePalette.enumerated()), id: \.offset) { index, color in
                        Button {
                            controller.selectColor(at: index)
                        } label: {
                            Circle()
                                .fill(Color(uiColor: color))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle().strokeBorder(
                                        Color.primary.opacity(controller.activeColorIndex == index ? 0.8 : 0.12),
                                        lineWidth: controller.activeColorIndex == index ? 2 : 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Colore \(index + 1)")
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }

            HStack(spacing: 4) {
                ForEach(AnnotationTool.allCases) { tool in
                    Button {
                        controller.tool = tool
                        applyMarkupIfNeeded(for: tool, controller: controller)
                    } label: {
                        Image(systemName: tool.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 42, height: 42)
                            .foregroundStyle(controller.tool == tool ? Color.white : Color.primary)
                            .background {
                                if controller.tool == tool {
                                    Circle().fill(Color.accentColor)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tool.label)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 520)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
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

    /// Tapping highlight or underline applies the markup to the current selection.
    /// If nothing is selected, the tool stays active for the next selection.
    private func applyMarkupIfNeeded(for tool: AnnotationTool, controller: PDFEditorController) {
        switch tool {
        case .highlight:
            controller.applyMarkup(.highlight)
        case .underline:
            controller.applyMarkup(.underline)
        default:
            break
        }
    }

    private func startQuiz(for controller: PDFEditorController) {
        let questions = StudyQuestionGenerator.makeQuestions(
            from: controller.document,
            title: item.title
        )
        quizLaunch = QuizLaunch(questions: questions, documentTitle: item.title)
    }
}
