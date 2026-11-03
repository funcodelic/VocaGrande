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

    /// The description of the meaning of one pair of words, shown under the word
    /// while the fields still hold that pair.
    @State private var gloss: String?

    /// The pair `gloss` describes, as `pairKey`. Editing a field hides the gloss, and
    /// putting the pair back brings it back.
    @State private var glossPairKey: String?
    @State private var checkResult: CheckResult?
    @State private var isChecking = false

    /// The lexeme this screen is showing or has just saved, whose senses are listed.
    @State private var savedLexeme: Lexeme?
    @State private var isFindingSenses = false

    /// A note under the senses, such as "No other meanings found." or an error.
    @State private var senseMessage: String?
    @FocusState private var focusedField: Field?

    /// The cursor in each field, so a letter from the keyboard strip lands where the
    /// cursor is.
    @State private var nativeSelection: TextSelection?
    @State private var targetSelection: TextSelection?

    init(lexeme: Lexeme? = nil, language: Language, showsNativeFirst: Bool = false) {
        self.lexeme = lexeme
        self.language = language
        self.showsNativeFirst = showsNativeFirst
        _native = State(initialValue: lexeme?.englishMeaning ?? "")
        _target = State(initialValue: lexeme?.lemma ?? "")
        _gender = State(initialValue: lexeme?.gender)
        _savedLexeme = State(initialValue: lexeme)
        _gloss = State(initialValue: lexeme?.gloss)
        _glossPairKey = State(initialValue: lexeme.map { Self.pairKey(native: $0.englishMeaning ?? "", target: $0.lemma) })
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

    /// A pair of words as one comparable string: trimmed and lowercased.
    private static func pairKey(native: String, target: String) -> String {
        "\(native.trimmed.lowercased())|\(target.trimmed.lowercased())"
    }

    /// The gloss, only while the fields hold the pair it was made for.
    private var shownGloss: String? {
        glossPairKey == Self.pairKey(native: native, target: target) ? gloss : nil
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
                selection: isNative ? $nativeSelection : $targetSelection,
                prompt: Text("\(name) word")
                    .foregroundStyle(color.opacity(0.6))
            )
            .font(.title2)
            .foregroundStyle(color)
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
                    VStack(spacing: 6) {
                        textField(for: .target)
                        genderPicker
                    }
                } else {
                    VStack(spacing: 6) {
                        textField(for: .target)
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

                VStack(spacing: 10) {
                    Divider()

                    VStack(spacing: 8) {
                        preview

                        if let shownGloss {
                            Text(shownGloss)
                                .font(.callout)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 4)

                    if savedLexeme != nil {
                        Divider()
                    }
                }

                ScrollView {
                    sensesSection
                }
                .scrollBounceBehavior(.basedOnSize)

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
                ToolbarItemGroup(placement: .keyboard) {
                    specialCharacterStrip
                }
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

    /// The accented letters of the language of the focused field, in a strip above the
    /// keyboard. Empty for a field whose language needs none.
    @ViewBuilder
    private var specialCharacterStrip: some View {
        let code = focusedField == .native ? nativeCode : language.code
        let characters = AppLanguage.specialCharacters(forCode: code)

        if !characters.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(characters, id: \.self) { character in
                        Button {
                            insert(character)
                        } label: {
                            Text(character)
                                .font(.title3)
                                .frame(minWidth: 24)
                        }
                    }
                }
            }
        }
    }

    /// Puts `character` at the cursor of the focused field, replacing any selected
    /// text, and moves the cursor after it. Goes at the end when there's no cursor yet.
    private func insert(_ character: String) {
        if focusedField == .native {
            insert(character, into: &native, selection: &nativeSelection)
        } else {
            insert(character, into: &target, selection: &targetSelection)
        }
    }

    private func insert(_ character: String, into text: inout String, selection: inout TextSelection?) {
        var start = text.endIndex
        var end = text.endIndex
        if let selection, case .selection(let range) = selection.indices {
            start = range.lowerBound
            end = range.upperBound
        }

        let offset = text.distance(from: text.startIndex, to: start)
        text.replaceSubrange(start..<end, with: character)
        let cursor = text.index(text.startIndex, offsetBy: offset + character.count)
        selection = TextSelection(insertionPoint: cursor)
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
                    .foregroundStyle(language.color)
            }
            .font(.title2)
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
                let result = try await TranslationChecker().check(
                    native: native,
                    nativeLanguage: nativeName,
                    target: target,
                    targetLanguage: language.name,
                    gender: gender
                )
                if result.isCorrect, let problem = save(native: native, target: target, gloss: result.gloss) {
                    checkResult = .failed(problem)
                } else {
                    if result.isCorrect {
                        gloss = result.gloss
                        glossPairKey = Self.pairKey(native: native, target: target)
                    }
                    checkResult = result.isCorrect ? .correct : .tryAgain
                }
            } catch {
                checkResult = .failed(error.localizedDescription)
            }
            isChecking = false
        }
    }

    /// Asks for the word's other meanings, giving the ones it has so they aren't
    /// repeated, and adds every new one. The word is then believed to have all its
    /// meanings, so the button goes away.
    private func findMoreSenses() {
        guard let word = savedLexeme, !isFindingSenses else { return }
        isFindingSenses = true
        senseMessage = nil

        let known = word.orderedSenses.map { (translation: $0.translation, gloss: $0.gloss) }

        Task {
            do {
                let found = try await SenseFinder().findSenses(
                    lemma: word.lemma,
                    targetLanguage: language.name,
                    nativeLanguage: nativeName,
                    known: known
                )
                var added = 0
                for candidate in found where !word.hasSense(translation: candidate.translation, gloss: candidate.gloss) {
                    word.addSense(translation: candidate.translation, gloss: candidate.gloss)
                    added += 1
                }
                word.sensesAreExhaustive = true
                try modelContext.save()
                senseMessage = added == 0 ? "No other meanings found." : nil
            } catch {
                senseMessage = error.localizedDescription
            }
            isFindingSenses = false
        }
    }

    /// Every meaning the saved word has, with the button to look for more until a
    /// search for all of them has been done.
    @ViewBuilder
    private var sensesSection: some View {
        if let word = savedLexeme {
            VStack(alignment: .leading, spacing: 10) {
                Text("Other Definitions:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(word.orderedSenses) { sense in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(sense.translation)
                            .foregroundStyle(nativeColor)
                        if let gloss = sense.gloss {
                            Text(gloss)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.callout)
                }

                if !word.sensesAreExhaustive {
                    Button(action: findMoreSenses) {
                        if isFindingSenses {
                            ProgressView()
                        } else {
                            Text("Find more meanings")
                        }
                    }
                    .disabled(isFindingSenses)
                }

                if let senseMessage {
                    Text(senseMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }

    /// Saves the pair into the language right away, rather than waiting for
    /// SwiftData's autosave. A word already in this language keeps the senses it has
    /// (a lexeme is unique by language and lemma) and takes the gender chosen here. A
    /// pair with a new translation becomes another sense, and the word is no longer
    /// believed to have all its meanings. A known translation only fills in a missing
    /// gloss. Returns a message when the save fails.
    private func save(native: String, target: String, gloss: String?) -> String? {
        let lemma = target.lowercased()
        let code = language.code
        let descriptor = FetchDescriptor<Lexeme>(predicate: #Predicate { $0.lemma == lemma && $0.languageCode == code })

        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.gender = gender
            let match = existing.senses.first { $0.translation.lowercased() == native.lowercased() }
            if let match {
                if match.gloss == nil { match.gloss = gloss }
            } else {
                existing.addSense(translation: native, gloss: gloss)
                existing.sensesAreExhaustive = false
            }
            savedLexeme = existing
        } else {
            let new = Lexeme(lemma: lemma, englishMeaning: native, languageCode: language.code, gender: gender)
            new.gloss = gloss
            modelContext.insert(new)
            new.language = language
            savedLexeme = new
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
