//
//  FoundationModelsQuizGenerator.swift
//  pdf
//
//  Created on 13/11/2026.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct GeneratedQuizQuestion {
    @Guide(description: "Testo della domanda in italiano, chiaro e autonomo")
    var question: String

    @Guide(description: "La risposta corretta, breve e ricavata dal testo")
    var correctAnswer: String

    @Guide(description: "Tre risposte sbagliate brevi e plausibili", .count(3))
    var wrongAnswers: [String]

    @Guide(description: "Numero di pagina del PDF a cui si riferisce la domanda")
    var page: Int
}

@available(iOS 26.0, *)
@Generable
struct GeneratedQuiz {
    @Guide(description: "Domande a crocette basate sul testo fornito", .minimumCount(4), .maximumCount(8))
    var questions: [GeneratedQuizQuestion]
}

/// Uses Apple's on-device Foundation Models to write better multiple-choice
/// questions. When Apple Intelligence is unavailable, the caller falls back to
/// the heuristic generator.
@available(iOS 26.0, *)
enum FoundationModelsQuizGenerator {
    static var isAvailable: Bool {
#if targetEnvironment(simulator)
        // The simulator can report availability while the model service times out.
        return false
#else
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
#endif
    }

    static func makeQuestions(
        fromText text: String,
        pageCount: Int,
        limit: Int = 8
    ) async -> [StudyQuestion] {
        guard isAvailable, limit > 0 else { return [] }

        let source = String(text.prefix(6000))
        guard source.count > 200 else { return [] }

        let sourceForValidation = normalized(source)
        guard !sourceForValidation.isEmpty else { return [] }

        let session = LanguageModelSession(
            instructions: """
            Sei un teacher universitario italiano simpatico e preciso.
            Crei domande a crocette per aiutare lo studente a ripassare i suoi PDF.
            Usa esclusivamente le informazioni presenti nel testo fornito.
            La risposta corretta deve essere verificabile nel testo.
            Rispondi sempre in italiano.
            """
        )

        do {
            let response = try await session.respond(
                to: """
                Crea \(limit) domande a crocette sul testo qui sotto.
                Regole:
                - ogni domanda ha una sola risposta corretta e tre risposte sbagliate;
                - le risposte sbagliate devono essere plausibili ma chiaramente errate;
                - indica la pagina del PDF a cui si riferisce la domanda.
                Testo:
                \(source)
                """,
                generating: GeneratedQuiz.self,
                options: GenerationOptions(temperature: 0.3, maximumResponseTokens: 1600)
            )

            var seenQuestions = Set<String>()
            var questions: [StudyQuestion] = []

            for generated in response.content.questions {
                let question = generated.question.trimmingCharacters(in: .whitespacesAndNewlines)
                let correctAnswer = generated.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
                let wrongAnswers = generated.wrongAnswers.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                guard !question.isEmpty,
                      !correctAnswer.isEmpty,
                      wrongAnswers.count == 3,
                      wrongAnswers.allSatisfy({ !$0.isEmpty }) else {
                    continue
                }

                let questionKey = normalized(question)
                guard !questionKey.isEmpty,
                      seenQuestions.insert(questionKey).inserted else {
                    continue
                }

                // Reject answers that can't actually be found in the source
                // and choices that would make the question ambiguous.
                let correctKey = normalized(correctAnswer)
                guard !correctKey.isEmpty,
                      sourceForValidation.contains(correctKey) else {
                    continue
                }

                let wrongKeys = wrongAnswers.map { normalized($0) }
                guard wrongKeys.allSatisfy({
                    !$0.isEmpty
                        && !$0.contains(correctKey)
                        && !correctKey.contains($0)
                }) else {
                    continue
                }

                var choices = [correctAnswer] + wrongAnswers
                guard Set(choices.map { normalized($0) }).count == 4 else {
                    continue
                }

                choices.shuffle()
                guard let correctIndex = choices.firstIndex(where: {
                    $0.caseInsensitiveCompare(correctAnswer) == .orderedSame
                }) else {
                    continue
                }

                let page = pageCount > 0 && (1...pageCount).contains(generated.page)
                    ? generated.page
                    : nil

                questions.append(
                    StudyQuestion(
                        prompt: question,
                        choices: choices,
                        correctIndex: correctIndex,
                        page: page
                    )
                )

                if questions.count >= limit { break }
            }

            return questions
        } catch {
            return []
        }
    }

    /// Normalizes whitespace and case so the same answer/question can be
    /// compared reliably against the source text.
    private static func normalized(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }
}
#else
enum FoundationModelsQuizGenerator {
    static var isAvailable: Bool { false }

    static func makeQuestions(
        fromText text: String,
        pageCount: Int,
        limit: Int = 8
    ) async -> [StudyQuestion] {
        []
    }
}
#endif
