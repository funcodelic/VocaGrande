//
//  TranslationChecker.swift
//  VocaGrande
//
//  Created by Troy Mulder on 11/1/26.
//
//  Asks the model whether an English word and a Spanish word mean the same thing.

import Foundation

struct TranslationChecker {

    /// The developer message sent ahead of the pair. Asks for one word back so the
    /// reply is trivial to read.
    static let instructions = """
    You check vocabulary. You are given an English word or phrase and a Spanish word \
    or phrase. Decide whether the English is a correct translation of the Spanish. \
    Accept any valid translation, including synonyms, a conjugated or plural form of \
    the Spanish, and a missing "to" on an English verb. Ignore capitalization. Reject \
    a wrong meaning, a misspelling that changes the word, or a different word. \
    You are also given the article the learner chose for the Spanish word: el, la, or \
    na (no article, meaning the word is not a noun). If the Spanish word is a noun, \
    the article must be its correct gender, so reject el for a feminine noun and la for \
    a masculine one, and reject na. If the Spanish word is not a noun, the article \
    must be na. Reply with exactly one word: correct or incorrect.
    """

    private let service = ChatService()

    /// Returns whether `english` translates `spanish`, and whether `gender` is the
    /// right article for it (nil meaning "na", the word is not a noun).
    func isCorrect(english: String, spanish: String, gender: Gender?) async throws -> Bool {
        let reply = try await service.send([
            .developer(Self.instructions),
            .user("English: \(english)\nSpanish: \(spanish)\nArticle: \(gender?.article ?? "na")"),
        ])
        return reply.lowercased().hasPrefix("correct")
    }
}
