//
//  LibraryDocument.swift
//  pdf
//
//  Created on 13/11/2026.
//

import Foundation
import Observation
import PDFKit

/// A PDF stored inside the app's local library.
struct LibraryDocument: Identifiable, Hashable {
    let url: URL
    let pageCount: Int
    let modifiedAt: Date

    var id: URL { url }

    var title: String {
        url.deletingPathExtension().lastPathComponent
    }

    var pageCountText: String {
        pageCount == 1 ? "1 pagina" : "\(pageCount) pagine"
    }
}

/// Owns the folder where imported PDFs live and keeps the library list in sync.
@Observable
final class DocumentLibrary {
    private(set) var documents: [LibraryDocument] = []

    let folderURL: URL

    init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folderURL = documentsURL.appendingPathComponent("PDF", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        refresh()
    }

    // MARK: - Loading

    func refresh() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        documents = urls
            .filter { $0.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame }
            .compactMap { url -> LibraryDocument? in
                guard let pdf = PDFDocument(url: url) else { return nil }
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return LibraryDocument(url: url, pageCount: pdf.pageCount, modifiedAt: date)
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    // MARK: - Import / delete

    func importDocuments(from urls: [URL]) throws {
        var lastError: Error?
        for url in urls {
            do {
                try importDocument(from: url)
            } catch {
                lastError = error
            }
        }
        refresh()
        if let lastError { throw lastError }
    }

    private func importDocument(from source: URL) throws {
        let scopedAccess = source.startAccessingSecurityScopedResource()
        defer {
            if scopedAccess { source.stopAccessingSecurityScopedResource() }
        }

        guard PDFDocument(url: source) != nil else {
            throw LibraryError.invalidPDF(source.lastPathComponent)
        }

        let baseName = source.deletingPathExtension().lastPathComponent
        let destination = uniqueDestination(for: baseName)
        try FileManager.default.copyItem(at: source, to: destination)
    }

    func delete(_ document: LibraryDocument) {
        try? FileManager.default.removeItem(at: document.url)
        refresh()
    }

    // MARK: - Sample document

    @discardableResult
    func createSampleDocument() -> LibraryDocument? {
        let destination = uniqueDestination(for: "PDF di esempio")
        guard let data = SampleDocumentFactory.makePDFData() else { return nil }
        do {
            try data.write(to: destination, options: .atomic)
        } catch {
            return nil
        }
        refresh()
        return documents.first { $0.url == destination }
    }

    // MARK: - Helpers

    private func uniqueDestination(for baseName: String) -> URL {
        var destination = folderURL.appendingPathComponent(baseName + ".pdf")
        var counter = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = folderURL.appendingPathComponent("\(baseName) \(counter).pdf")
            counter += 1
        }
        return destination
    }
}

enum LibraryError: LocalizedError {
    case invalidPDF(String)

    var errorDescription: String? {
        switch self {
        case .invalidPDF(let name):
            "“\(name)” non sembra un PDF valido."
        }
    }
}
