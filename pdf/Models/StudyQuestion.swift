//
//  StudyQuestion.swift
//  pdf
//
//  Created on 13/11/2026.
//

import Foundation

struct StudyQuestion: Identifiable, Hashable, Sendable {
    let id: UUID
    let prompt: String
    let choices: [String]
    let correctIndex: Int
    let page: Int?
    let topic: String?

    nonisolated init(
        id: UUID = UUID(),
        prompt: String,
        choices: [String],
        correctIndex: Int,
        page: Int? = nil,
        topic: String? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.choices = choices
        self.correctIndex = correctIndex
        self.page = page
        self.topic = topic
    }
}

/// Text extracted from one PDF page. Keeping the page number together with the
/// string lets the generator run off the main thread without PDFKit.
struct StudyPageText: Sendable {
    let number: Int
    let text: String
}

/// Builds multiple-choice questions directly from the text of a PDF.
/// The heuristic picks a meaningful keyword from a sentence, hides it, and uses
/// other keywords from the document as plausible wrong answers.
nonisolated enum StudyQuestionGenerator {
    private struct Candidate {
        let sentence: String
        let keyword: String
        let page: Int
    }

    static func makeQuestions(from pages: [StudyPageText], limit: Int = 8) -> [StudyQuestion] {
        var candidates: [Candidate] = []
        var keywordPool: [String] = []

        for page in pages {
            let text = normalize(page.text)
            guard !text.isEmpty else { continue }

            for sentence in sentences(in: text) {
                guard let keyword = keyword(in: sentence) else { continue }
                candidates.append(Candidate(sentence: sentence, keyword: keyword, page: page.number))
                keywordPool.append(contentsOf: keywords(in: sentence))
            }
        }

        var seenPrompts = Set<String>()
        var questions: [StudyQuestion] = []

        for candidate in candidates {
            guard let wordRange = candidate.sentence.range(of: candidate.keyword, options: [.caseInsensitive]) else { continue }

            let prompt = candidate.sentence.replacingCharacters(in: wordRange, with: "_____")
            var seenDistractors = Set<String>()
            let uniqueDistractors = keywordPool.filter { word in
                guard word.caseInsensitiveCompare(candidate.keyword) != .orderedSame,
                      !prompt.localizedCaseInsensitiveContains(word) else {
                    return false
                }
                // Deduplicate case-insensitively so the same word can't appear
                // twice (for example "memoria" and "Memoria").
                return seenDistractors.insert(word.lowercased()).inserted
            }

            guard uniqueDistractors.count >= 3 else { continue }

            var choices = Array(uniqueDistractors.shuffled().prefix(3))
            choices.append(candidate.keyword)
            choices.shuffle()

            guard let correctIndex = choices.firstIndex(where: {
                $0.caseInsensitiveCompare(candidate.keyword) == .orderedSame
            }) else { continue }

            let question = StudyQuestion(
                prompt: "Completa la frase: “\(prompt)”",
                choices: choices,
                correctIndex: correctIndex,
                page: candidate.page
            )

            guard seenPrompts.insert(question.prompt).inserted else { continue }
            questions.append(question)

            if questions.count >= limit { break }
        }

        return questions
    }

    // MARK: - Text processing

    private static func normalize(_ text: String) -> String {
        var lines = text.components(separatedBy: .newlines)

        // Drop a short heading at the top of the page, otherwise the heading
        // gets glued to the first sentence and the cloze becomes confusing.
        if let headingIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
           isHeading(in: lines, at: headingIndex) {
            lines.remove(at: headingIndex)
        }

        return lines
            .joined(separator: "\n")
            .replacingOccurrences(of: "-\n", with: "")
            .replacingOccurrences(of: "\u{00AD}", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }

    private static func isHeading(in lines: [String], at index: Int) -> Bool {
        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        let wordCount = trimmed.split(separator: " ").count
        let terminalCharacters: Set<Character> = [".", "!", "?", ":", ";", ","]

        guard let last = trimmed.last else { return false }
        guard trimmed.count < 90,
              wordCount <= 12,
              !terminalCharacters.contains(last) else {
            return false
        }

        // A wrapped body line continues with a lowercase word. A real heading
        // is followed by a new sentence that starts with a capital letter (or
        // by the end of the page).
        let nextLine = lines[(index + 1)...]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }

        guard let nextLine, let first = nextLine.first else { return true }
        return first.isUppercase
    }

    private static func sentences(in text: String) -> [String] {
        let source = text as NSString
        var result: [String] = []

        source.enumerateSubstrings(
            in: NSRange(location: 0, length: source.length),
            options: [.bySentences, .substringNotRequired]
        ) { _, range, _, _ in
            let sentence = source.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.count >= 55, sentence.count <= 260 {
                result.append(sentence)
            }
        }

        return result
    }

    private static func keyword(in sentence: String) -> String? {
        sentence
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { $0.count >= 6 && !stopwords.contains($0.lowercased()) }
            // Using a word that appears only once avoids leaving the answer
            // visible elsewhere in the sentence.
            .filter { occurrenceCount(of: $0, in: sentence) == 1 }
            .max { $0.count < $1.count }
    }

    private static func occurrenceCount(of word: String, in sentence: String) -> Int {
        var count = 0
        var searchStart = sentence.startIndex

        while searchStart < sentence.endIndex,
              let range = sentence.range(
                  of: word,
                  options: [.caseInsensitive],
                  range: searchStart..<sentence.endIndex
              ) {
            count += 1
            if count > 1 { return count }
            searchStart = range.upperBound
        }

        return count
    }

    private static func keywords(in sentence: String) -> [String] {
        sentence
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { $0.count >= 5 && !stopwords.contains($0.lowercased()) }
    }

    // MARK: - Stopwords

    private static let stopwords: Set<String> = [
        "della", "delle", "degli", "dello", "dalla", "dalle", "dagli", "dallo",
        "questo", "questa", "questi", "queste", "quello", "quella", "quelli", "quelle",
        "anche", "sono", "essere", "come", "nella", "nelle", "negli", "nello",
        "perché", "perche", "quando", "dove", "quale", "quali", "molto", "molta",
        "molti", "molte", "senza", "sopra", "sotto", "tra", "fra", "alla", "alle",
        "agli", "allo", "dal", "del", "dei", "nel", "nei", "con", "una", "uno",
        "gli", "the", "and", "that", "with", "from", "this", "these", "those",
        "which", "their", "there", "into", "have", "has", "was", "were", "will",
        "would", "could", "should", "about", "other", "than", "then", "them",
        "they", "been", "being", "when", "where", "what", "who", "whom", "whose",
        "also", "such", "some", "more", "most", "only", "very", "just", "over",
        "under", "between", "perché", "poi", "già", "ancora", "ogni", "tutto",
        "tutti", "tutte", "dopo", "prima", "durante", "verso", "queste", "quindi"
    ]
}
