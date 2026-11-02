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

    /// The Spanish definite article: "el" or "la".
    var article: String {
        switch self {
        case .masculine: "el"
        case .feminine: "la"
        }
    }
}

/// One word of vocabulary, persisted with SwiftData. There is one `Lexeme` per
/// dictionary word: `lemma` is unique, so a word met again in a later capture is
/// the same lexeme, now linked to both captures.
@Model
final class Lexeme {

    /// The word in its dictionary form, lowercase: the infinitive of a verb, the
    /// singular of a noun or adjective. Unique across the store, so saving a second
    /// lexeme with the same lemma upserts into the first rather than duplicating it.
    /// `BookPdfController` looks up existing lexemes by lemma before inserting any,
    /// so an existing word keeps the meaning it already has.
    @Attribute(.unique) var lemma: String

    /// A dictionary-short English meaning. Nil until translated.
    var englishMeaning: String?

    /// The language the word is in, as a two-letter code: "es" for Spanish.
    var languageCode: String

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
