//
//  LibraryView.swift
//  pdf
//
//  Created on 13/11/2026.
//

import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(TeacherStore.self) private var teacherStore

    @State private var library = DocumentLibrary()
    @State private var isImporting = false
    @State private var isTeacherSettingsPresented = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    teacherCard
                    documentsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("La mia libreria")
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
        .task(id: document.url) {
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
}
