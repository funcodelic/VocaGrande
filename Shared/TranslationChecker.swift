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

        /// The part of speech of the target word in the matched meaning; `unknown`
        /// for a wrong pair.
        let partOfSpeech: PartOfSpeech
    }

    /// The developer message sent ahead of the pair. Asks for a fixed three-line reply
    /// so it is trivial to read. `expectsInfinitive` is true when the learner wrote
    /// the native word as an infinitive ("to speak"), which adds a stricter rule: the
    /// target must itself be the infinitive of a verb.
    static func instructions(native: String, target: String, expectsInfinitive: Bool = false) -> String {
        let infinitiveRule = expectsInfinitive ? """
            The learner has marked the \(native) as the infinitive of a verb, because it \
            starts with "to". So the \(target) must itself be the infinitive of a verb, \
            its dictionary form. If the \(target) is a conjugated form, a participle, a \
            gerund, a noun, or any other word, reply incorrect even when the meaning \
            matches: "to speak" does not match Italian parli, because parli is a \
            conjugated form and the infinitive is parlare. The \(native) must also be \
            the exact infinitive translation of that verb. \

            """ : ""

        return """
        You check vocabulary pairs for exact equivalence, as a bilingual dictionary \
        would list them. You are given a \(native) word or phrase and a \(target) word \
        or phrase. Decide whether the \(native) is an exact translation of the \(target). \
        Judge form for form, not only meaning: the grammatical form of the \(target) \
        (person, number, tense, mood, gender, infinitive, participle, gerund, singular \
        or plural) must be the form the \(native) expresses. An inflected \(target) \
        matches only a \(native) with the same inflection: Italian parli matches \
        "you speak", not "speak" and not "to speak"; a plural matches a plural. Accept \
        a synonym only when it is a standard dictionary translation of that exact form. \
        A missing infinitive marker on a verb (such as "to" in English) is accepted \
        only when the \(target) is an infinitive. Ignore capitalization. Reject a wrong \
        meaning, a looser or only related meaning, a paraphrase or explanation, a \
        different form of the right word, a misspelling that changes the word, or a \
        different word. \
        \(infinitiveRule)\
        You are also given the grammatical gender the learner chose for the \(target) \
        word: masculine, feminine, or na (no gender, meaning the word is not a noun). \
        If the \(target) word is a noun, the gender must be correct, so reject masculine \
        for a feminine noun and feminine for a masculine one, and reject na. If the \
        \(target) word is not a noun, the gender must be na. \
        Reply on exactly three lines. Line 1: one word, correct or incorrect. Line 2: when \
        correct, a gloss of the meaning in which the \(native) translates the \(target), \
        written in \(native): a short description of at most eight words, lowercase, \
        with no final period, that tells this meaning apart from the \(target) word's \
        other meanings (for example, for Spanish banca and English bank: financial \
        institution). Line 3: when correct, the part of speech of the \(target) word in \
        that meaning, as one lowercase word from: \(PartOfSpeech.replyNames). When \
        incorrect, leave lines 2 and 3 empty.
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
        // An English word written as "to ..." asserts the infinitive of a verb, so the
        // check is told to hold the target word to that.
        let expectsInfinitive = nativeLanguage == "English" && native.lowercased().hasPrefix("to ")

        let reply = try await service.send([
            .developer(Self.instructions(native: nativeLanguage, target: targetLanguage, expectsInfinitive: expectsInfinitive)),
            .user("\(nativeLanguage): \(native)\n\(targetLanguage): \(target)\nGender: \(gender?.rawValue ?? "na")"),
        ])

        let lines = reply
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let isCorrect = lines.first?.lowercased().hasPrefix("correct") ?? false
        let gloss = isCorrect && lines.count > 1 ? lines[1] : nil
        let partOfSpeech = isCorrect && lines.count > 2 ? PartOfSpeech(reply: lines[2]) : .unknown
        return Result(isCorrect: isCorrect, gloss: gloss, partOfSpeech: partOfSpeech)
    }
}
