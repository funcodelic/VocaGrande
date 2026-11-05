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

    /// The part of speech the last check reported for the target word; `unknown`
    /// until a check, and again when the target word is edited.
    @State private var partOfSpeech: PartOfSpeech

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
        _partOfSpeech = State(initialValue: lexeme?.partOfSpeech ?? .unknown)
        _savedLexeme = State(initialValue: lexeme)
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

    /// Whether what is in the fields is the pair already saved and checked: the word
    /// is saved, its translation is one of its senses, and the gender is unchanged.
    /// The check button is then drawn quietly so it doesn't ask to be pressed again.
    /// It still works, and turns bright as soon as anything is edited.
    private var isVerified: Bool {
        guard let word = savedLexeme else { return false }
        let translation = native.trimmed.lowercased()
        return target.trimmed.lowercased() == word.lemma
            && gender == word.gender
            && word.translations.contains { $0.lowercased() == translation }
    }

    private var title: String {
        guard lexeme != nil else { return "New Word" }
        let word = showsNativeFirst ? native : target
        return word.isEmpty ? "New Word" : word
    }

    /// The color of the bottom field's language, used for the check button under it.
    private var bottomColor: Color {
        showsNativeFirst ? language.color : nativeColor
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
            .submitLabel(isTop ? .next : .continue)
            .onSubmit {
                if isTop {
                    focusedField = bottomField
                } else {
                    check()
                }
            }
        }
    }

    /// Toggles "to " at the start of the English field. Adds it with the cursor after
    /// it, ready for the verb; a field that already starts with "to " loses it instead,
    /// with the cursor at the start.
    private func insertTo() {
        if native.lowercased().hasPrefix("to ") {
            native.removeFirst(3)
            nativeSelection = TextSelection(insertionPoint: native.startIndex)
        } else {
            native = "to " + native
            nativeSelection = TextSelection(insertionPoint: native.index(native.startIndex, offsetBy: 3))
        }
        focusedField = .native
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
                .tint(isVerified ? Color.secondary : bottomColor)
                .disabled(!canCheck)

                checkResultView

                VStack(spacing: 10) {
                    preview
                        .padding(.vertical, 4)

                    // The line above the meanings only matters once there is a list.
                    if (savedLexeme?.senses.count ?? 0) > 1 {
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
            .onChange(of: target) {
                checkResult = nil
                partOfSpeech = .unknown
            }
            .onAppear {
                if lexeme == nil { focusedField = topField }
            }
        }
    }

    /// Above the keyboard: the accented letters of the language of the focused field,
    /// and for the English field of an English speaker, "to (verb infinitive)", which
    /// puts "to " in front of the word. Nothing for a field whose language needs neither.
    @ViewBuilder
    private var specialCharacterStrip: some View {
        let code = focusedField == .native ? nativeCode : language.code
        let characters = AppLanguage.specialCharacters(forCode: code)
        let showsTo = focusedField == .native && nativeCode == "en"

        if !characters.isEmpty || showsTo {
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

                    if showsTo {
                        Button(action: insertTo) {
                            HStack(spacing: 4) {
                                Text("to (verb infinitive)")
                                    .foregroundStyle(.secondary)
                                //Text("(verb infinitive)")
                                    .foregroundStyle(.tertiary)
                            }
                            .font(.title3)
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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let gender {
                    Text(gender.article(for: language.code))
                        .foregroundStyle(.secondary)
                }
                Text(target.trimmed.lowercased())
                    .foregroundStyle(language.color)
                if partOfSpeech != .unknown {
                    Text(partOfSpeech.rawValue)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
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
                .foregroundStyle(nativeColor)
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
                if result.isCorrect { partOfSpeech = result.partOfSpeech }
                if result.isCorrect, let problem = save(
                    native: native,
                    target: target,
                    gloss: result.gloss,
                    partOfSpeech: result.partOfSpeech
                ) {
                    checkResult = .failed(problem)
                } else {
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

        let known = word.sortedSenses.map { (translation: $0.translation, gloss: $0.gloss) }

        Task {
            do {
                let found = try await SenseFinder().findSenses(
                    lemma: word.lemma,
                    targetLanguage: language.name,
                    nativeLanguage: nativeName,
                    partOfSpeech: word.partOfSpeech,
                    gender: word.gender,
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
                if word.sensesAreExhaustive {
                    Text("Meanings:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Button(action: findMoreSenses) {
                        if isFindingSenses {
                            ProgressView()
                        } else {
                            Text("Find more meanings")
                        }
                    }
                    .disabled(isFindingSenses)
                }

                ForEach(word.sortedSenses) { sense in
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
    /// SwiftData's autosave. A word already in this language with the same lemma and
    /// part of speech keeps the senses it has (a lexeme is unique by language, lemma
    /// and part of speech) and takes the gender chosen here. A word saved with no
    /// part of speech yet (from a capture) is taken over by the first check that
    /// reports one. The same spelling as a different part of speech is a separate
    /// lexeme. A pair with a new translation becomes another sense, and the word is
    /// no longer believed to have all its meanings. A known translation only fills in
    /// a missing gloss. Returns a message when the save fails.
    private func save(native: String, target: String, gloss: String?, partOfSpeech: PartOfSpeech) -> String? {
        let lemma = target.lowercased()
        let code = language.code
        let descriptor = FetchDescriptor<Lexeme>(predicate: #Predicate { $0.lemma == lemma && $0.languageCode == code })
        // The learner wrote the English infinitive ("to lead") and the check agrees the
        // word is a verb: the word is asserted to be the infinitive of its verb.
        let assertsInfinitive = partOfSpeech == .verb && native.lowercased().hasPrefix("to ")
        let sameSpelling = (try? modelContext.fetch(descriptor)) ?? []
        let match = sameSpelling.first { $0.partOfSpeech == partOfSpeech }
            ?? (partOfSpeech == .unknown ? nil : sameSpelling.first { $0.partOfSpeech == .unknown })

        if let existing = match {
            existing.partOfSpeech = partOfSpeech
            if assertsInfinitive { existing.isInfinitive = true }
            existing.gender = gender
            if existing.primaryTranslation == nil { existing.primaryTranslation = native }
            let sense = existing.senses.first { $0.translation.lowercased() == native.lowercased() }
            if let sense {
                if sense.gloss == nil { sense.gloss = gloss }
            } else {
                existing.addSense(translation: native, gloss: gloss)
                existing.sensesAreExhaustive = false
            }
            savedLexeme = existing
        } else {
            let new = Lexeme(
                lemma: lemma,
                englishMeaning: native,
                languageCode: language.code,
                gender: gender,
                partOfSpeech: partOfSpeech,
                isInfinitive: assertsInfinitive
            )
            new.senses.first?.gloss = gloss
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
