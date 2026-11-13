//
//  StudySessionView.swift
//  pdf
//
//  Created on 13/11/2026.
//

import SwiftUI

struct StudySessionView: View {
    let questions: [StudyQuestion]
    let teacher: TeacherProfile
    let documentTitle: String

    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var selectedIndex: Int?
    @State private var score = 0
    @State private var isFinished = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                if questions.isEmpty {
                    ContentUnavailableView(
                        "Nessuna domanda",
                        systemImage: "text.badge.xmark",
                        description: Text("Questo PDF non contiene abbastanza testo per generare le domande.")
                    )
                } else if isFinished {
                    resultContent
                } else {
                    questionContent
                }
            }
            .navigationTitle("Interrogazione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }

    // MARK: - Question

    private var currentQuestion: StudyQuestion {
        questions[index]
    }

    private var questionContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if selectedIndex == nil {
                        teacherBubble
                    }
                    progressHeader
                    questionCard
                    if selectedIndex != nil {
                        feedbackCard
                    }
                    choicesList
                }
                .padding()
            }

            nextButton
        }
    }

    private var teacherBubble: some View {
        HStack(alignment: .top, spacing: 12) {
            TeacherAvatarView(profile: teacher, size: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(teacher.name)
                    .font(.subheadline.weight(.bold))
                Text("Leggi la domanda con calma e scegli la risposta che ti convince di più.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer(minLength: 0)
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Domanda \(index + 1) di \(questions.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Punteggio \(score)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.identity)
            }
            ProgressView(
                value: Double(index) + (selectedIndex == nil ? 0 : 1),
                total: Double(questions.count)
            )
            .tint(.indigo)
        }
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(documentTitle)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(currentQuestion.prompt)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let page = currentQuestion.page {
                Label("Pagina \(page)", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var choicesList: some View {
        VStack(spacing: 6) {
            ForEach(Array(currentQuestion.choices.enumerated()), id: \.offset) { choiceIndex, choice in
                choiceButton(choice: choice, index: choiceIndex)
            }
        }
    }

    private func choiceButton(choice: String, index choiceIndex: Int) -> some View {
        Button {
            select(choiceIndex)
        } label: {
            HStack(spacing: 12) {
                Text(letter(for: choiceIndex))
                    .font(.subheadline.weight(.bold))
                    .frame(width: 28, height: 28)
                    .background(badgeColor(for: choiceIndex), in: Circle())

                Text(choice)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                if let selectedIndex, selectedIndex == choiceIndex || choiceIndex == currentQuestion.correctIndex {
                    Image(systemName: choiceIndex == currentQuestion.correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(choiceIndex == currentQuestion.correctIndex ? .green : .red)
                }
            }
            .padding(10)
            .background(choiceBackground(for: choiceIndex), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(choiceBorder(for: choiceIndex), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedIndex != nil)
    }

    private var feedbackCard: some View {
        HStack(alignment: .top, spacing: 10) {
            TeacherAvatarView(profile: teacher, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(isAnswerCorrect ? "Esatto!" : "Non ci siamo, ma è così che si impara.")
                    .font(.subheadline.weight(.bold))
                if !isAnswerCorrect {
                    Text("La risposta corretta è “\(currentQuestion.choices[currentQuestion.correctIndex])”.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let page = currentQuestion.page {
                    Text("Ripassa a pagina \(page).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: isAnswerCorrect ? "checkmark.seal.fill" : "lightbulb.fill")
                .foregroundStyle(isAnswerCorrect ? .green : .orange)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var nextButton: some View {
        Button {
            advance()
        } label: {
            Text(index + 1 == questions.count ? "Vedi il risultato" : "Prossima domanda")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(selectedIndex == nil)
        .padding()
        .background(.bar)
    }

    // MARK: - Result

    private var resultContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                TeacherAvatarView(profile: teacher, size: 132)
                    .padding(.top, 24)

                Text(resultTitle)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("\(score) / \(questions.count)")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.indigo)

                Text(resultMessage)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)

                ProgressView(value: Double(score), total: Double(max(questions.count, 1)))
                    .tint(.indigo)
                    .padding(.horizontal, 40)

                VStack(spacing: 10) {
                    Button {
                        restart()
                    } label: {
                        Text("Riprova")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Chiudi") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Derived state

    private var isAnswerCorrect: Bool {
        selectedIndex == currentQuestion.correctIndex
    }

    private var resultTitle: String {
        let ratio = Double(score) / Double(max(questions.count, 1))
        switch ratio {
        case 0.8...: return "Ottimo lavoro!"
        case 0.5..<0.8: return "Ci siamo quasi"
        default: return "Da ripassare"
        }
    }

    private var resultMessage: String {
        let ratio = Double(score) / Double(max(questions.count, 1))
        switch ratio {
        case 0.8...: return "Hai capito i punti principali di “\(documentTitle)”. Un altro giro e sei pronto."
        case 0.5..<0.8: return "Buona base. Rileggi le pagine indicate e riprova: il Teacher è qui per questo."
        default: return "Nessun problema: riapri il PDF, ripassa le pagine segnalate e fatti interrogare di nuovo."
        }
    }

    // MARK: - Styling helpers

    private func letter(for choiceIndex: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        return letters[min(choiceIndex, letters.count - 1)]
    }

    private func badgeColor(for choiceIndex: Int) -> Color {
        guard let selectedIndex else {
            return Color.primary.opacity(0.08)
        }
        if choiceIndex == currentQuestion.correctIndex {
            return .green.opacity(0.25)
        }
        if choiceIndex == selectedIndex {
            return .red.opacity(0.2)
        }
        return Color.primary.opacity(0.08)
    }

    private func choiceBackground(for choiceIndex: Int) -> Color {
        guard let selectedIndex else {
            return Color(uiColor: .secondarySystemGroupedBackground)
        }
        if choiceIndex == currentQuestion.correctIndex {
            return .green.opacity(0.12)
        }
        if choiceIndex == selectedIndex {
            return .red.opacity(0.10)
        }
        return Color(uiColor: .secondarySystemGroupedBackground)
    }

    private func choiceBorder(for choiceIndex: Int) -> Color {
        guard let selectedIndex else {
            return Color.primary.opacity(0.06)
        }
        if choiceIndex == currentQuestion.correctIndex {
            return .green.opacity(0.5)
        }
        if choiceIndex == selectedIndex {
            return .red.opacity(0.45)
        }
        return Color.primary.opacity(0.06)
    }

    // MARK: - Actions

    private func select(_ choiceIndex: Int) {
        guard selectedIndex == nil else { return }
        selectedIndex = choiceIndex
        if choiceIndex == currentQuestion.correctIndex {
            score += 1
        }
    }

    private func advance() {
        if index + 1 < questions.count {
            index += 1
            selectedIndex = nil
        } else {
            isFinished = true
        }
    }

    private func restart() {
        index = 0
        selectedIndex = nil
        score = 0
        isFinished = false
    }
}

#Preview {
    StudySessionView(
        questions: [
            StudyQuestion(
                prompt: "Completa la frase: “La memoria a lungo termine si costruisce con il _____ attivo.”",
                choices: ["recupero", "riposo", "divertimento", "rumore"],
                correctIndex: 0,
                page: 1
            )
        ],
        teacher: .sample,
        documentTitle: "PDF di esempio"
    )
}
