//
//  Lexeme.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/5/26.
//

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

    /// A dictionary-short English meaning. Nil until translated.
    var englishMeaning: String?

    /// A short description of the one meaning `englishMeaning` expresses, such as
    /// "financial institution" for banca / bank. Nil until a check supplies it.
    /// Stands in until `Sense` owns glosses (build plan stage C).
    var gloss: String?

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
        self.englishMeaning = englishMeaning
        self.languageCode = languageCode
        self.gender = gender
    }
}
