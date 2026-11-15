//
//  PencilDrawingStore.swift
//  pdf
//
//  Created on 13/11/2026.
//

import Foundation
import PencilKit

/// Stores PencilKit drawings per page in a sidecar file next to the app's
/// support data. The PDF itself keeps highlights, ink annotations and notes;
/// PencilKit content lives here so it can be restored at full fidelity.
final class PencilDrawingStore {
    private let fileURL: URL
    private var encodedDrawings: [String: Data]

    init(documentURL: URL) {
        let supportURL = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory

        let folderURL = supportURL.appendingPathComponent("FratmPDF/Drawings", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        fileURL = folderURL.appendingPathComponent(Self.fileName(for: documentURL))
        encodedDrawings = Self.loadDrawings(from: fileURL)
    }

    func loadAll() -> [Int: PKDrawing] {
        var drawings: [Int: PKDrawing] = [:]
        for (key, data) in encodedDrawings {
            guard let pageIndex = Int(key),
                  let drawing = try? PKDrawing(data: data) else { continue }
            drawings[pageIndex] = drawing
        }
        return drawings
    }

    func save(_ drawing: PKDrawing, pageIndex: Int) {
        encodedDrawings[String(pageIndex)] = drawing.dataRepresentation()
    }

    func flush() {
        guard let data = try? JSONEncoder().encode(encodedDrawings) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func clear() {
        encodedDrawings.removeAll()
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func removeStore(for documentURL: URL) {
        let supportURL = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )) ?? FileManager.default.temporaryDirectory
        let fileURL = supportURL
            .appendingPathComponent("FratmPDF/Drawings", isDirectory: true)
            .appendingPathComponent(fileName(for: documentURL))
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func fileName(for documentURL: URL) -> String {
        let base = documentURL.deletingPathExtension().lastPathComponent
        let safeBase = base.replacingOccurrences(of: "/", with: "-")
        return "\(safeBase).drawings.json"
    }

    private static func loadDrawings(from url: URL) -> [String: Data] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Data].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
