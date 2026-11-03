//
//  LexemeDetailiOS.swift
//  VocaGrande-iOS
//
//  Created by Troy Mulder on 11/1/26.
//

import SwiftData
import SwiftUI

/// The add screen: type an English word and its Spanish match, tap the check, and
/// ChatGPT says whether they match. A correct pair is saved as a lexeme.
struct LexemeDetailiOS: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private enum Field {
        case english
        case spanish
    }

    private enum Verdict {
        case correct
        case tryAgain
        case failed(String)
    }

    /// The word being viewed, or nil when adding a new one.
    let lexeme: Lexeme?

    /// The language of the list this screen was opened from: "es" or "en". The
    /// field for that language goes on top, and it names the title for a saved word.
    let language: String

    @State private var english: String
    @State private var spanish: String
    @State private var gender: Gender?
    @State private var verdict: Verdict?
    @State private var isChecking = false
    @FocusState private var focusedField: Field?

    init(lexeme: Lexeme? = nil, language: String = "es") {
        self.lexeme = lexeme
        self.language = language
        _english = State(initialValue: lexeme?.englishMeaning ?? "")
        _spanish = State(initialValue: lexeme?.lemma ?? "")
        _gender = State(initialValue: lexeme?.gender)
    }

    private var canCheck: Bool {
        !english.trimmed.isEmpty && !spanish.trimmed.isEmpty && !isChecking
    }

    private var isCorrect: Bool {
        if case .correct = verdict { true } else { false }
    }

    private var title: String {
        guard lexeme != nil else { return "New Word" }
        let word = language == "en" ? english : spanish
        return word.isEmpty ? "New Word" : word
    }

    private var topField: Field { language == "en" ? .english : .spanish }

    private var bottomField: Field { language == "en" ? .spanish : .english }

    private func textField(for field: Field) -> some View {
        let isEnglish = field == .english
        let name = isEnglish ? "English word" : "Spanish word"
        let isTop = field == topField

        return VStack(alignment: .leading, spacing: 4) {
            Text(isEnglish ? "English" : "Spanish")
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .padding(.leading, 4)

            TextField(
                "",
                text: isEnglish ? $english : $spanish,
                prompt: Text(name)
                    .foregroundStyle((isTop ? Color.blue : Color.primary).opacity(0.6))
            )
            .font(.title2)
            .focused($focusedField, equals: field)
            .submitLabel(isTop ? .next : .done)
            .onSubmit {
                if isTop {
                    focusedField = bottomField
                } else {
                    check()
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if language == "en" {
                    textField(for: .english)
                        .foregroundStyle(.blue)
                    VStack(spacing: 6) {
                        textField(for: .spanish)
                        genderPicker
                    }
                } else {
                    VStack(spacing: 6) {
                        textField(for: .spanish)
                            .foregroundStyle(.blue)
                        genderPicker
                    }
                    textField(for: .english)
                }

                Button(action: check) {
                    if isChecking {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(!canCheck)

                verdictView
                
                Divider()
                
                preview
                    .padding(.top, 24)

                Spacer()
            }
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(16)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .clipShape(Circle())
                }
            }
            .onChange(of: english) { verdict = nil }
            .onChange(of: spanish) { verdict = nil }
            .onAppear {
                if lexeme == nil { focusedField = topField }
            }
        }
    }

    /// "el | la | na" under the Spanish field: the chosen one is white, the others
    /// secondary. "na" (no gender, a nil `gender`) is the default.
    private var genderPicker: some View {
        HStack(spacing: 24) {
            genderButton("el", .masculine)
            genderButton("la", .feminine)
            genderButton("na", nil)
        }
    }

    private func genderButton(_ article: String, _ value: Gender?) -> some View {
        Button {
            gender = value
        } label: {
            Text(article)
                .font(.title3)
                .foregroundStyle(gender == value ? Color.blue : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    /// The Spanish word as it will be saved, built up as the learner types and
    /// picks: the article in secondary, then the word. No article shows for na.
    @ViewBuilder
    private var preview: some View {
        if !spanish.trimmed.isEmpty {
            HStack(spacing: 8) {
                if let gender {
                    Text(gender.article)
                        .foregroundStyle(.secondary)
                }
                Text(spanish.trimmed.lowercased())
                    .foregroundStyle(Color.primary)
            }
            .font(.title2)
            .padding(.vertical, 8)
            .keyframeAnimator(initialValue: 1.0, trigger: isCorrect) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(1.3, duration: 0.15, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
            }
        }
    }

    @ViewBuilder
    private var verdictView: some View {
        switch verdict {
        case .correct:
            Text("Correct")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.green)
        case .tryAgain:
            Text("Try Again")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
        case .failed(let message):
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
        case nil:
            EmptyView()
        }
    }

    private func check() {
        guard canCheck else { return }
        focusedField = nil
        isChecking = true

        let english = english.trimmed
        let spanish = spanish.trimmed

        Task {
            do {
                let isCorrect = try await TranslationChecker().isCorrect(english: english, spanish: spanish, gender: gender)
                if isCorrect {
                    save(english: english, spanish: spanish)
                }
                verdict = isCorrect ? .correct : .tryAgain
            } catch {
                verdict = .failed(error.localizedDescription)
            }
            isChecking = false
        }
    }

    /// Saves the pair. A word already in the store keeps the meaning it has
    /// (`lemma` is unique), but takes the gender chosen here.
    private func save(english: String, spanish: String) {
        let lemma = spanish.lowercased()
        let descriptor = FetchDescriptor<Lexeme>(predicate: #Predicate { $0.lemma == lemma })

        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.gender = gender
            return
        }

        modelContext.insert(Lexeme(lemma: lemma, englishMeaning: english, languageCode: "es", gender: gender))
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    LexemeDetailiOS()
        .modelContainer(for: [Lexeme.self, TextSelectionItem.self], inMemory: true)
}
