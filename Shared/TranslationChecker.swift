//
//  TranslationChecker.swift
//  VocaGrande
//
//  Created by Troy Mulder on 11/1/26.
//
//  Asks the model whether a word in the learner's native language and a word in the
//  language being learned mean the same thing, and which meaning that is.

import Foundation

struct TranslationChecker {

    /// What a check found: whether the pair matches, and for a match, the gloss of
    /// the meaning it matches in.
    struct Result {
        let isCorrect: Bool

        /// A short description of the matched meaning; nil for a wrong pair.
        let gloss: String?
    }

    /// The developer message sent ahead of the pair. Asks for a fixed two-line reply
    /// so it is trivial to read.
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
        Reply on exactly two lines. Line 1: one word, correct or incorrect. Line 2: when \
        correct, a gloss of the meaning in which the \(native) translates the \(target), \
        written in \(native): a short description of at most eight words, lowercase, \
        with no final period, that tells this meaning apart from the \(target) word's \
        other meanings (for example, for Spanish banca and English bank: financial \
        institution). When incorrect, leave line 2 empty.
        """
    }

    private let service = ChatService()

    /// Checks whether `native` translates `target`, and whether `gender` is right
    /// for it (nil meaning "na", the word is not a noun).
    func check(
        native: String,
        nativeLanguage: String,
        target: String,
        targetLanguage: String,
        gender: Gender?
    ) async throws -> Result {
        let reply = try await service.send([
            .developer(Self.instructions(native: nativeLanguage, target: targetLanguage)),
            .user("\(nativeLanguage): \(native)\n\(targetLanguage): \(target)\nGender: \(gender?.rawValue ?? "na")"),
        ])

        let lines = reply
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let isCorrect = lines.first?.lowercased().hasPrefix("correct") ?? false
        let gloss = isCorrect && lines.count > 1 ? lines[1] : nil
        return Result(isCorrect: isCorrect, gloss: gloss)
    }
}
