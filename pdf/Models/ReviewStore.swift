//
//  ReviewStore.swift
//  pdf
//
//  Created on 13/11/2026.
//

import Foundation
import Observation

/// A mistake the student should see again, scheduled with simple spaced repetition.
struct ReviewItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var documentTitle: String
    var prompt: String
    var choices: [String]
    var correctIndex: Int
    var page: Int?
    var dueDate: Date
    var stage: Int
    var missCount: Int
}

/// Keeps track of wrong answers and schedules the automatic review.
@Observable
final class ReviewStore {
    private(set) var items: [ReviewItem] = []

    private static let storageKey = "review.items.v1"
    private static let day: TimeInterval = 60 * 60 * 24
    private static let intervals: [TimeInterval] = [1 * day, 3 * day]
    private static let requiredCorrectReviews = 3

    init() {
        load()
    }

    var totalCount: Int { items.count }
    var dueCount: Int { dueItems.count }

    var dueItems: [ReviewItem] {
        let now = Date()
        return items
            .filter { Self.isValid($0) && $0.dueDate <= now }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var nextDueDate: Date? {
        let now = Date()
        return items
            .filter { Self.isValid($0) }
            .map(\.dueDate)
            .filter { $0 > now }
            .min()
    }

    /// Called after a normal quiz: only wrong answers are saved.
    /// New mistakes are due immediately so the student can review them right away.
    func recordMiss(question: StudyQuestion, documentTitle: String) {
        if let index = items.firstIndex(where: {
            $0.prompt == question.prompt && $0.documentTitle == documentTitle
        }) {
            items[index].missCount += 1
            items[index].stage = 0
            items[index].dueDate = Date()
            items[index].choices = question.choices
            items[index].correctIndex = question.correctIndex
            items[index].page = question.page
        } else {
            items.append(
                ReviewItem(
                    documentTitle: documentTitle,
                    prompt: question.prompt,
                    choices: question.choices,
                    correctIndex: question.correctIndex,
                    page: question.page,
                    dueDate: Date(),
                    stage: 0,
                    missCount: 1
                )
            )
        }
        persist()
    }

    /// Grades a question inside a review session.
    /// Three correct reviews in a row remove the item.
    func gradeReview(prompt: String, documentTitle: String, correct: Bool) {
        guard let index = items.firstIndex(where: {
            $0.prompt == prompt && $0.documentTitle == documentTitle
        }) else { return }

        if correct {
            items[index].stage += 1
            if items[index].stage >= Self.requiredCorrectReviews {
                items.remove(at: index)
            } else {
                items[index].dueDate = Date().addingTimeInterval(Self.intervals[items[index].stage - 1])
            }
        } else {
            items[index].stage = 0
            items[index].missCount += 1
            items[index].dueDate = Date()
        }

        persist()
    }

    func questionsForReview() -> [StudyQuestion] {
        dueItems.compactMap { item in
            guard Self.isValid(item) else { return nil }
            return StudyQuestion(
                prompt: item.prompt,
                choices: item.choices,
                correctIndex: item.correctIndex,
                page: item.page,
                topic: item.documentTitle
            )
        }
    }

    func removeItems(forDocumentTitle title: String) {
        let previousCount = items.count
        items.removeAll { $0.documentTitle == title }
        if items.count != previousCount {
            persist()
        }
    }

    func removeAll() {
        items.removeAll()
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([ReviewItem].self, from: data) else {
            return
        }

        let validItems = decoded.filter(Self.isValid)
        items = validItems
        if validItems.count != decoded.count {
            persist()
        }
    }

    nonisolated private static func isValid(_ item: ReviewItem) -> Bool {
        guard item.stage >= 0,
              item.choices.count >= 2,
              item.choices.indices.contains(item.correctIndex) else {
            return false
        }
        return Set(item.choices.map { $0.lowercased() }).count == item.choices.count
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
