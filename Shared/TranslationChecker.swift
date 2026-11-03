//
//  TranslationChecker.swift
//  VocaGrande
//
//  Created by Troy Mulder on 11/1/26.
//
//  Asks the model whether a word in the learner's native language and a word in the
//  language being learned mean the same thing.

import Foundation

struct TranslationChecker {

    /// The developer message sent ahead of the pair. Asks for one word back so the
    /// reply is trivial to read.
    static func instructions(native: String, target: String) -> String {
        """
        You check vocabulary. You are given a \(native) word or phrase and a \(target) \
        word or phrase. Decide whether the \(native) is a correct translation of the \
        \(target). Accept any valid translation, including synonyms, a conjugated or \
        plural form of the \(target), and a missing infinitive marker on a verb (such as \
        "to" in English). Ignore capitalization. Reject a wrong meaning, a misspelling \
        that changes the word, or a different word. \
        You are also given the grammatical gender the learner chose for the \(target) \
        word: masculine, feminine, or na (no gender, meaning the word is not a noun). \
        If the \(target) word is a noun, the gender must be correct, so reject masculine \
        for a feminine noun and feminine for a masculine one, and reject na. If the \
        \(target) word is not a noun, the gender must be na. \
        Reply with exactly one word: correct or incorrect.
        """
    }

    private let service = ChatService()

    /// Returns whether `native` translates `target`, and whether `gender` is right
    /// for it (nil meaning "na", the word is not a noun).
    func isCorrect(
        native: String,
        nativeLanguage: String,
        target: String,
        targetLanguage: String,
        gender: Gender?
    ) async throws -> Bool {
        let reply = try await service.send([
            .developer(Self.instructions(native: nativeLanguage, target: targetLanguage)),
            .user("\(nativeLanguage): \(native)\n\(targetLanguage): \(target)\nGender: \(gender?.rawValue ?? "na")"),
        ])
        return reply.lowercased().hasPrefix("correct")
    }
}
