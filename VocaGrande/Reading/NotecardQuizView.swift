//
//  NotecardQuizView.swift
//  VocaGrande
//
//  Created by Troy Mulder on 10/1/26.
//

import SwiftData
import SwiftUI

/// Quizzes the saved lexemes in random order: shows a word in one language, you
/// type it in the other, and the lexeme's correct/incorrect count is updated.
struct NotecardQuizView: View {

    /// Which language is shown as the prompt.
    enum Direction: String, CaseIterable, Identifiable {
        case spanish = "Spanish"
        case english = "English"

        var id: String { rawValue }
    }

    /// What the answer area is showing.
    private enum Phase {
        case asking
        case result(correct: Bool)
    }

    @Environment(\.dismiss) private var dismiss

    @Query private var lexemes: [Lexeme]

    @State private var direction: Direction = .spanish
    @State private var queue: [Lexeme] = []
    @State private var current: Lexeme?
    @State private var answer = ""
    @State private var phase: Phase = .asking
    @FocusState private var answerFocused: Bool

    /// Words answered correctly at least once since this sheet opened.
    @State private var correctThisSession: Set<PersistentIdentifier> = []

    /// Only translated words can be quizzed, since the English side is needed.
    private var quizzable: [Lexeme] {
        lexemes.filter { !($0.englishMeaning ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Words answered correctly at least once, across all sessions.
    private var knownCount: Int {
        lexemes.filter { $0.notecardCorrectCount > 0 }.count
    }

    private func times(_ count: Int) -> String {
        count == 1 ? "1 time" : "\(count) times"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("You know \(knownCount) \(knownCount == 1 ? "word" : "words")")
                    .foregroundStyle(.secondary)
                + Text(correctThisSession.isEmpty ? "" : " (+\(correctThisSession.count))")
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("Direction", selection: $direction) {
                    ForEach(Direction.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .help("Done")
            }
            .padding()

            Divider()

            Group {
                if let current {
                    card(for: current)
                } else {
                    Text("No translated words to quiz yet")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .frame(minWidth: 440, minHeight: 520)
        .onAppear { advance() }
        .onChange(of: direction) { advance() }
    }

    // MARK: - Card

    @ViewBuilder
    private func card(for lexeme: Lexeme) -> some View {
        VStack(spacing: 20) {
            Text(prompt(for: lexeme))
                .font(.system(size: 40, weight: .semibold))
                .multilineTextAlignment(.center)

            switch phase {
            case .asking:
                TextField(direction == .spanish ? "English" : "Spanish", text: $answer)
                    .textFieldStyle(.roundedBorder)
                    .font(.title2)
                    .frame(maxWidth: 320)
                    .focused($answerFocused)
                    .onSubmit { submit(lexeme) }
                    .onAppear { answerFocused = true }

            case .result(let correct):
                VStack(spacing: 4) {
                    Text(correct ? "Correct" : "Incorrect")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(correct ? Color.green : Color.red)

                    Text(correct
                         ? "You got it right \(times(lexeme.notecardCorrectCount))"
                         : "That's \(times(lexeme.notecardIncorrectCount)) you got it wrong")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if !correct {
                        Text("Answer: \(expectedAnswers(for: lexeme).first ?? "")")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Next") { advance() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - Engine

    private func prompt(for lexeme: Lexeme) -> String {
        direction == .spanish ? lexeme.lemma : (lexeme.englishMeaning ?? "")
    }

    /// The accepted answers: the lemma, or, for every sense, its translation and each
    /// comma/semicolon-separated part of it.
    private func expectedAnswers(for lexeme: Lexeme) -> [String] {
        switch direction {
        case .spanish:
            var answers: [String] = []
            for meaning in lexeme.translations {
                answers.append(meaning)
                let parts = meaning.split(whereSeparator: { ",;".contains($0) })
                answers.append(contentsOf: parts.map(String.init))
            }
            return answers
        case .english:
            return [lexeme.lemma]
        }
    }

    /// Ignores case and whitespace but not accents: "está" and "esta" differ.
    private func normalized(_ text: String) -> String {
        text.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .precomposedStringWithCanonicalMapping
    }

    private func submit(_ lexeme: Lexeme) {
        let given = normalized(answer)
        guard !given.isEmpty else { return }

        let correct = expectedAnswers(for: lexeme).contains { normalized($0) == given }
        if correct {
            lexeme.notecardCorrectCount += 1
            correctThisSession.insert(lexeme.persistentModelID)
        } else {
            lexeme.notecardIncorrectCount += 1
        }
        phase = .result(correct: correct)
    }

    /// Moves to the next random word, reshuffling once every word has been shown.
    private func advance() {
        if queue.isEmpty { queue = quizzable.shuffled() }
        current = queue.popLast()
        answer = ""
        phase = .asking
        answerFocused = true
    }
}

#Preview {
    NotecardQuizView()
        .modelContainer(for: Lexeme.self, inMemory: true)
}
