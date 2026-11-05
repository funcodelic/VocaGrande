//
//  PartOfSpeech.swift
//  VocaGrande
//
//  Created by Troy Mulder on 11/5/26.
//

import Foundation

/// A word's part of speech: the category of word it is, which is part of what makes
/// a `Lexeme` unique (language, lemma, part of speech). `unknown` is for words saved
/// before the check reported one, and is filled in the next time the word is checked.
enum PartOfSpeech: String, Codable, CaseIterable {
    case unknown
    case noun
    case verb
    case adjective
    case adverb
    case pronoun
    case article
    case preposition
    case conjunction
    case interjection

    /// The names the check is asked to answer with, for its instructions.
    static var replyNames: String {
        allCases.filter { $0 != .unknown }.map(\.rawValue).joined(separator: ", ")
    }

    /// Reads a model's one-word answer, tolerating case, a final period, and
    /// "determiner" for an article. Anything else is `unknown`.
    init(reply: String) {
        let word = reply.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
        self = word == "determiner" ? .article : (Self(rawValue: word) ?? .unknown)
    }
}
