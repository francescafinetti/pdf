//
//  StudyQuestion.swift
//  pdf
//
//  Created on 13/11/2026.
//

import Foundation
import PDFKit

struct StudyQuestion: Identifiable, Hashable {
    let id: UUID
    let prompt: String
    let choices: [String]
    let correctIndex: Int
    let page: Int?

    init(
        id: UUID = UUID(),
        prompt: String,
        choices: [String],
        correctIndex: Int,
        page: Int? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.choices = choices
        self.correctIndex = correctIndex
        self.page = page
    }
}

/// Builds multiple-choice questions directly from the text of a PDF.
/// The heuristic picks a meaningful keyword from a sentence, hides it, and uses
/// other keywords from the document as plausible wrong answers.
enum StudyQuestionGenerator {
    private struct Candidate {
        let sentence: String
        let keyword: String
        let page: Int
    }

    static func makeQuestions(from document: PDFDocument, title: String, limit: Int = 8) -> [StudyQuestion] {
        var candidates: [Candidate] = []
        var keywordPool: [String] = []

        let pageLimit = min(document.pageCount, 40)
        guard pageLimit > 0 else {
            return fallbackQuestions(title: title, pageCount: document.pageCount)
        }

        for pageIndex in 0..<pageLimit {
            guard let page = document.page(at: pageIndex), let rawText = page.string else { continue }
            let text = normalize(rawText)

            for sentence in sentences(in: text) {
                guard let keyword = keyword(in: sentence) else { continue }
                candidates.append(Candidate(sentence: sentence, keyword: keyword, page: pageIndex + 1))
                keywordPool.append(contentsOf: keywords(in: sentence))
            }
        }

        var seenPrompts = Set<String>()
        var questions: [StudyQuestion] = []

        for candidate in candidates {
            guard let wordRange = candidate.sentence.range(of: candidate.keyword, options: [.caseInsensitive]) else { continue }

            let prompt = candidate.sentence.replacingCharacters(in: wordRange, with: "_____")
            let uniqueDistractors = Array(
                Set(
                    keywordPool.filter {
                        $0.caseInsensitiveCompare(candidate.keyword) != .orderedSame
                            && !prompt.localizedCaseInsensitiveContains($0)
                    }
                )
            )

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

        if questions.count < 4 {
            let extra = fallbackQuestions(title: title, pageCount: document.pageCount)
            questions.append(contentsOf: extra.prefix(4 - questions.count))
        }

        return questions
    }

    // MARK: - Text processing

    private static func normalize(_ text: String) -> String {
        var lines = text.components(separatedBy: .newlines)

        // Drop a short heading at the top of the page, otherwise the heading
        // gets glued to the first sentence and the cloze becomes confusing.
        if let headingIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
           isHeading(lines[headingIndex]) {
            lines.remove(at: headingIndex)
        }

        return lines
            .joined(separator: "\n")
            .replacingOccurrences(of: "-\n", with: "")
            .replacingOccurrences(of: "\u{00AD}", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }

    private static func isHeading(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let wordCount = trimmed.split(separator: " ").count
        let terminalCharacters: Set<Character> = [".", "!", "?", ":", ";", ","]

        guard let last = trimmed.last else { return false }
        return trimmed.count < 90
            && wordCount <= 12
            && !terminalCharacters.contains(last)
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
            .max { $0.count < $1.count }
    }

    private static func keywords(in sentence: String) -> [String] {
        sentence
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { $0.count >= 5 && !stopwords.contains($0.lowercased()) }
    }

    // MARK: - Fallbacks

    private static func fallbackQuestions(title: String, pageCount: Int) -> [StudyQuestion] {
        let correctPages = max(pageCount, 1)
        let pageChoices = [correctPages, correctPages + 2, correctPages + 5, correctPages + 9].shuffled()
        let pageIndex = pageChoices.firstIndex(of: correctPages) ?? 0

        return [
            StudyQuestion(
                prompt: "Quante pagine ha “\(title)”?",
                choices: pageChoices.map(String.init),
                correctIndex: pageIndex
            ),
            StudyQuestion(
                prompt: "Qual è la strategia migliore prima di rispondere a una domanda a crocette?",
                choices: [
                    "Rileggere la parte del PDF collegata alla domanda",
                    "Scegliere sempre la risposta più lunga",
                    "Rispondere a caso e andare avanti",
                    "Leggere solo il titolo del documento"
                ],
                correctIndex: 0
            ),
            StudyQuestion(
                prompt: "Cosa conviene fare dopo aver sbagliato una domanda?",
                choices: [
                    "Ignorare l'errore",
                    "Tornare alla pagina indicata e ripassare quel passaggio",
                    "Ricomincere il PDF dall'inizio",
                    "Cambiare documento"
                ],
                correctIndex: 1
            ),
            StudyQuestion(
                prompt: "Come si mantiene alta la concentrazione durante lo studio?",
                choices: [
                    "Studiando per ore senza pause",
                    "Alternando sessioni brevi e pause",
                    "Leggendo tutto la sera prima dell'esame",
                    "Tenendo il telefono accanto"
                ],
                correctIndex: 1
            )
        ]
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
