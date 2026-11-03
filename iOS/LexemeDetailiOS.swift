//
//  LexemeDetailiOS.swift
//  VocaGrande-iOS
//
//  Created by Troy Mulder on 11/1/26.
//

import SwiftData
import SwiftUI

/// The add screen: type a word in the native language and its match in the language
/// being learned, tap the check, and ChatGPT says whether they match. A correct pair
/// is saved as a lexeme of that language.
struct LexemeDetailiOS: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage(ProfileKeys.nativeLanguage) private var nativeCode = ""
    @AppStorage(ProfileKeys.nativeLanguageColor) private var nativeColorName = ""

    private enum Field {
        case native
        case target
    }

    private enum CheckResult {
        case correct
        case tryAgain
        case failed(String)
    }

    /// The word being viewed, or nil when adding a new one.
    let lexeme: Lexeme?

    /// The language being learned; a saved word belongs to it.
    let language: Language

    /// Whether the list this screen was opened from shows the native language first.
    /// The field for that language goes on top.
    let showsNativeFirst: Bool

    @State private var native: String
    @State private var target: String
    @State private var gender: Gender?
    @State private var checkResult: CheckResult?
    @State private var isChecking = false
    @FocusState private var focusedField: Field?

    init(lexeme: Lexeme? = nil, language: Language, showsNativeFirst: Bool = false) {
        self.lexeme = lexeme
        self.language = language
        self.showsNativeFirst = showsNativeFirst
        _native = State(initialValue: lexeme?.englishMeaning ?? "")
        _target = State(initialValue: lexeme?.lemma ?? "")
        _gender = State(initialValue: lexeme?.gender)
    }

    private var nativeName: String {
        nativeCode.isEmpty ? "Native" : AppLanguage.name(forCode: nativeCode)
    }

    private var nativeColor: Color {
        (LanguageColor(rawValue: nativeColorName) ?? .blue).color
    }

    /// The color of the side listed first, used for the buttons so they hint which
    /// language the word is being added from.
    private var accentColor: Color {
        showsNativeFirst ? nativeColor : language.color
    }

    private var canCheck: Bool {
        !native.trimmed.isEmpty && !target.trimmed.isEmpty && !nativeCode.isEmpty && !isChecking
    }

    private var isCorrect: Bool {
        if case .correct = checkResult { true } else { false }
    }

    private var title: String {
        guard lexeme != nil else { return "New Word" }
        let word = showsNativeFirst ? native : target
        return word.isEmpty ? "New Word" : word
    }

    private var topField: Field { showsNativeFirst ? .native : .target }

    private var bottomField: Field { showsNativeFirst ? .target : .native }

    private func textField(for field: Field) -> some View {
        let isNative = field == .native
        let name = isNative ? nativeName : language.name
        let isTop = field == topField
        let color = isNative ? nativeColor : language.color

        return VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .padding(.leading, 4)

            TextField(
                "",
                text: isNative ? $native : $target,
                prompt: Text("\(name) word")
                    .foregroundStyle((isTop ? color : Color.primary).opacity(0.6))
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
                if showsNativeFirst {
                    textField(for: .native)
                        .foregroundStyle(nativeColor)
                    VStack(spacing: 6) {
                        textField(for: .target)
                        genderPicker
                    }
                } else {
                    VStack(spacing: 6) {
                        textField(for: .target)
                            .foregroundStyle(language.color)
                        genderPicker
                    }
                    textField(for: .native)
                }

                Button(action: check) {
                    if isChecking {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .disabled(!canCheck)

                checkResultView

                Divider()

                preview
                    .padding(.top, 24)

                Spacer()
            }
            .tint(accentColor)
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
                    .tint(accentColor)
                    .clipShape(Circle())
                }
            }
            .onChange(of: native) { checkResult = nil }
            .onChange(of: target) { checkResult = nil }
            .onAppear {
                if lexeme == nil { focusedField = topField }
            }
        }
    }

    /// "el | la | na" under the target-language field: the chosen one is in the
    /// language's color, the others secondary. "na" (no gender, a nil `gender`) is
    /// the default.
    private var genderPicker: some View {
        HStack(spacing: 24) {
            genderButton(Gender.masculine.article(for: language.code), .masculine)
            genderButton(Gender.feminine.article(for: language.code), .feminine)
            genderButton("na", nil)
        }
    }

    private func genderButton(_ article: String, _ value: Gender?) -> some View {
        Button {
            gender = value
        } label: {
            Text(article)
                .font(.title3)
                .foregroundStyle(gender == value ? accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    /// The word being learned as it will be saved, built up as the learner types and
    /// picks: the article in secondary, then the word. No article shows for na.
    @ViewBuilder
    private var preview: some View {
        if !target.trimmed.isEmpty {
            HStack(spacing: 8) {
                if let gender {
                    Text(gender.article(for: language.code))
                        .foregroundStyle(.secondary)
                }
                Text(target.trimmed.lowercased())
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
    private var checkResultView: some View {
        switch checkResult {
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

        let native = native.trimmed
        let target = target.trimmed

        Task {
            do {
                let isCorrect = try await TranslationChecker().isCorrect(
                    native: native,
                    nativeLanguage: nativeName,
                    target: target,
                    targetLanguage: language.name,
                    gender: gender
                )
                if isCorrect, let problem = save(native: native, target: target) {
                    checkResult = .failed(problem)
                } else {
                    checkResult = isCorrect ? .correct : .tryAgain
                }
            } catch {
                checkResult = .failed(error.localizedDescription)
            }
            isChecking = false
        }
    }

    /// Saves the pair into the language right away, rather than waiting for
    /// SwiftData's autosave. A word already in this language keeps the meaning it has
    /// (`lemma` is unique), but takes the gender chosen here. Returns a message when
    /// the word can't be saved, which is when the same spelling is already a word in
    /// another language (until lemma stops being unique on its own).
    private func save(native: String, target: String) -> String? {
        let lemma = target.lowercased()
        let descriptor = FetchDescriptor<Lexeme>(predicate: #Predicate { $0.lemma == lemma })

        if let existing = (try? modelContext.fetch(descriptor))?.first {
            guard existing.languageCode == language.code else {
                return "\"\(lemma)\" is already saved as a \(AppLanguage.name(forCode: existing.languageCode)) word."
            }
            existing.gender = gender
        } else {
            let new = Lexeme(lemma: lemma, englishMeaning: native, languageCode: language.code, gender: gender)
            modelContext.insert(new)
            new.language = language
        }

        do {
            try modelContext.save()
            return nil
        } catch {
            return "Couldn't save: \(error.localizedDescription)"
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    LexemeDetailiOS(language: Language(code: "es", color: .blue))
        .modelContainer(for: [Language.self, Lexeme.self, TextSelectionItem.self], inMemory: true)
}
