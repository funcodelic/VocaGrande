//
//  Lexeme.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/5/26.
//

import Foundation
import SwiftData

/// A noun's grammatical gender. Spanish and Italian use only the first two.
enum Gender: String, Codable {
    case masculine
    case feminine

    /// The definite article in a language: "el" or "la" in Spanish, "il" or "la" in
    /// Italian. Other languages show "m" or "f" until they are given articles.
    func article(for languageCode: String) -> String {
        switch (languageCode, self) {
        case ("es", .masculine): "el"
        case ("es", .feminine): "la"
        case ("it", .masculine): "il"
        case ("it", .feminine): "la"
        case (_, .masculine): "m"
        case (_, .feminine): "f"
        }
    }
}

/// One word of vocabulary, persisted with SwiftData. There is one `Lexeme` per
/// dictionary word in each language: (`languageCode`, `lemma`) is unique, so a word
/// met again in a later capture is the same lexeme, now linked to both captures,
/// while Spanish "casa" and Italian "casa" are two lexemes.
@Model
final class Lexeme {

    #Unique<Lexeme>([\.languageCode, \.lemma])

    /// The word in its dictionary form, lowercase: the infinitive of a verb, the
    /// singular of a noun or adjective. Unique within its language, so saving a
    /// second lexeme with the same language and lemma upserts into the first rather
    /// than duplicating it. Callers look up existing lexemes by language and lemma
    /// before inserting any, so an existing word keeps the meaning it already has.
    var lemma: String

    /// The word's meanings, owned by it. Read them through `orderedSenses`.
    @Relationship(deleteRule: .cascade, inverse: \Sense.lexeme) var senses: [Sense] = []

    /// Whether a search for all of the word's meanings has been done (a full lookup,
    /// or "find more meanings"), so `senses` is believed complete. False when the
    /// word was added by asserting one meaning, and false again when a meaning is
    /// added by hand afterwards.
    var sensesAreExhaustive: Bool = false

    /// The language the word is in, as a two-letter code: "es" for Spanish.
    var languageCode: String

    /// The language this word belongs to. Nil only for words saved before languages
    /// existed; `Language.adoptOrphans` links those on launch.
    var language: Language?

    /// The grammatical gender of a noun. Nil for words that have none (verbs,
    /// adverbs) and for words not yet marked.
    var gender: Gender?

    /// How many times the word was answered correctly in the notecard quiz, in
    /// either direction.
    var notecardCorrectCount: Int = 0

    /// How many times the word was answered wrongly in the notecard quiz, in
    /// either direction.
    var notecardIncorrectCount: Int = 0

    /// Every capture this word was parsed out of. The inverse of
    /// `TextSelectionItem.lexemes`; deleting a capture leaves its words behind.
    @Relationship(inverse: \TextSelectionItem.lexemes) var selections: [TextSelectionItem] = []

    init(
        lemma: String,
        englishMeaning: String? = nil,
        languageCode: String,
        gender: Gender? = nil
    ) {
        self.lemma = lemma
        self.languageCode = languageCode
        self.gender = gender
        self.englishMeaning = englishMeaning
    }

    /// The senses in order, first to last.
    var orderedSenses: [Sense] {
        senses.sorted { $0.order < $1.order }
    }

    /// The first sense's translation: the dictionary-short native meaning shown in
    /// lists. Nil until translated. Setting it changes the first sense, or makes one.
    var englishMeaning: String? {
        get { orderedSenses.first?.translation }
        set {
            guard let newValue, !newValue.isEmpty else { return }
            if let first = orderedSenses.first {
                first.translation = newValue
            } else {
                senses.append(Sense(translation: newValue, order: 0))
            }
        }
    }

    /// The first sense's gloss, such as "financial institution" for banca / bank.
    /// Nil until a check supplies it; setting it needs a first sense.
    var gloss: String? {
        get { orderedSenses.first?.gloss }
        set { orderedSenses.first?.gloss = newValue }
    }

    /// Every sense's translation, for quizzing: any of them is a right answer.
    var translations: [String] {
        orderedSenses.map(\.translation).filter { !$0.isEmpty }
    }

    /// Whether `translation` and `gloss` describe a meaning the word already has: the
    /// same translation, with the same gloss or no gloss yet.
    func hasSense(translation: String, gloss: String?) -> Bool {
        senses.contains { sense in
            Self.normalized(sense.translation) == Self.normalized(translation)
                && (sense.gloss == nil || Self.normalized(sense.gloss ?? "") == Self.normalized(gloss ?? ""))
        }
    }

    /// Adds a sense after the existing ones and returns it.
    @discardableResult
    func addSense(translation: String, gloss: String?) -> Sense {
        let sense = Sense(translation: translation, gloss: gloss, order: (senses.map(\.order).max() ?? -1) + 1)
        senses.append(sense)
        return sense
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
