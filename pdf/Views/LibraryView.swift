//
//  LibraryView.swift
//  pdf
//
//  Created on 13/11/2026.
//

import PDFKit
import SwiftUI
import UniformTypeIdentifiers

private struct ReviewLaunch: Identifiable {
    let id = UUID()
    let questions: [StudyQuestion]
}

struct LibraryView: View {
    @Environment(TeacherStore.self) private var teacherStore
    @Environment(ReviewStore.self) private var reviewStore

    @State private var library = DocumentLibrary()
    @State private var isImporting = false
    @State private var isTeacherSettingsPresented = false
    @State private var reviewLaunch: ReviewLaunch?
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    teacherCard

                    // Re-evaluate the "due" dates periodically even if the
                    // library stays open and nothing else changes.
                    if reviewStore.totalCount > 0 {
                        TimelineView(.periodic(from: .now, by: 60)) { _ in
                            reviewSection
                        }
                    }

                    documentsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("La mia libreria")
            .onAppear {
                // Refresh when coming back from the reader so edited PDFs
                // update their page count, date and thumbnail.
                library.refresh()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Aggiungi PDF")
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .sheet(isPresented: $isTeacherSettingsPresented) {
                TeacherSettingsView()
            }
            .sheet(item: $reviewLaunch) { launch in
                StudySessionView(
                    questions: launch.questions,
                    teacher: teacherStore.profile,
                    documentTitle: "Ripasso errori",
                    isReview: true,
                    onAnswered: { question, correct in
                        reviewStore.gradeReview(
                            prompt: question.prompt,
                            documentTitle: question.topic ?? "",
                            correct: correct
                        )
                    }
                )
            }
            .navigationDestination(for: LibraryDocument.self) { document in
                PDFReaderView(item: document)
            }
            .alert(
                "Ops",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { isPresented in
                        if !isPresented { errorMessage = nil }
                    }
                )
            ) {
                Button("Ok") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Teacher card

    private var teacherCard: some View {
        Button {
            isTeacherSettingsPresented = true
        } label: {
            HStack(spacing: 16) {
                TeacherAvatarView(profile: teacherStore.profile, size: 76)

                VStack(alignment: .leading, spacing: 4) {
                    Text("IL TUO TEACHER")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(teacherStore.profile.name)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text("Domande a crocette generate dai tuoi PDF")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo.opacity(0.18), Color.teal.opacity(0.14)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Personalizza nome e aspetto del Teacher")
    }

    // MARK: - Review

    private var reviewSection: some View {
        Group {
            if reviewStore.totalCount > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ripasso")
                        .font(.title2.bold())

                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.indigo)
                            .frame(width: 38, height: 38)
                            .background(Color.indigo.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            if reviewStore.dueCount > 0 {
                                Text("\(reviewStore.dueCount) \(reviewStore.dueCount == 1 ? "domanda da ripassare" : "domande da ripassare")")
                                    .font(.subheadline.weight(.semibold))
                                Text("Gli errori tornano finché non li sai.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Tutto ripassato")
                                    .font(.subheadline.weight(.semibold))
                                if let nextDueDate = reviewStore.nextDueDate {
                                    Text("Prossimo ripasso: \(nextDueDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer(minLength: 8)

                        if reviewStore.dueCount > 0 {
                            Button("Ripassa") {
                                startReview()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(14)
                    .background(
                        Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
            }
        }
    }

    // MARK: - Documents

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("I tuoi PDF")
                    .font(.title2.bold())
                Spacer()
                if !library.documents.isEmpty {
                    Text("\(library.documents.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if library.documents.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    ForEach(library.documents) { document in
                        NavigationLink(value: document) {
                            DocumentCard(document: document)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                reviewStore.removeItems(forDocumentTitle: document.title)
                                PencilDrawingStore.removeStore(for: document.url)
                                library.delete(document)
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nessun PDF", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Importa gli appunti del corso oppure crea un PDF di esempio per provare il Teacher.")
        } actions: {
            Button("Importa PDF") {
                isImporting = true
            }
            .buttonStyle(.borderedProminent)

            Button("Crea un PDF di esempio") {
                createSampleDocument()
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            do {
                try library.importDocuments(from: urls)
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func createSampleDocument() {
        guard library.createSampleDocument() != nil else {
            errorMessage = "Non riesco a creare il PDF di esempio."
            return
        }
    }

    private func startReview() {
        let questions = reviewStore.questionsForReview()
        guard !questions.isEmpty else { return }
        reviewLaunch = ReviewLaunch(questions: questions)
    }
}

private struct DocumentCard: View {
    let document: LibraryDocument

    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))

                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                } else {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(0.75, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            )

            Text(document.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)

            Text(document.pageCountText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: document.modifiedAt) {
            thumbnail = Self.makeThumbnail(for: document.url)
        }
    }

    private static func makeThumbnail(for url: URL) -> UIImage? {
        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else { return nil }
        return page.thumbnail(of: CGSize(width: 300, height: 400), for: .cropBox)
    }
}

#Preview {
    LibraryView()
        .environment(TeacherStore())
        .environment(ReviewStore())
}
