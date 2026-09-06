//
//  WordParser.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/5/26.
//
//  Parses the cleaned text of a capture into its vocabulary: every distinct word
//  in the book's language, in dictionary form, each with a short English meaning.
//  One request both parses and translates. The result becomes the item's
//  `lexemes`, by way of `BookPdfController`.

import Foundation

struct WordParser {

    /// One word out of the text, as the API returns it: the dictionary form and
    /// its English meaning.
    struct Word: Decodable {
        let lemma: String
        let meaning: String
    }

    /// The two-letter code of the language whose words to keep: "es" for Spanish.
    /// Words in any other language are left out.
    let languageCode: String

    private let service = ChatService()

    init(languageCode: String = "es") {
        self.languageCode = languageCode
    }

    /// The language's English name for the instructions: "Spanish" for "es".
    var language: String {
        Locale(identifier: "en").localizedString(forLanguageCode: languageCode) ?? languageCode
    }

    /// The developer message sent ahead of the text. Lives here, with the code
    /// that sends it, rather than as a copy on every item in the store.
    var instructions: String {
        """
        List the \(language) vocabulary in this text. It comes from a \(language) \
        textbook and may mix in some English. Include every distinct \(language) word, \
        articles, pronouns and prepositions too. Leave out words in other languages, \
        numbers, and proper names. Give each word in its dictionary form, lowercase: \
        the infinitive of a verb, the singular of a noun, the masculine singular of an \
        adjective. Give each word's English meaning as briefly as a dictionary would: \
        a word or two, a short phrase at most. Reply with only a JSON array of objects \
        with "lemma" and "meaning" keys, no code fences and no commentary, like this: \
        [{"lemma":"comer","meaning":"to eat"},{"lemma":"casa","meaning":"house"}]
        """
    }

    /// Returns the distinct words in `text`, each with its meaning.
    func parse(_ text: String) async throws -> [Word] {
        let reply = try await service.send([
            .developer(instructions),
            .user(text.trimmingCharacters(in: .whitespacesAndNewlines)),
        ])
        return try Self.words(in: reply)
    }

    /// Decodes the JSON array in the reply, tolerating anything wrapped around it
    /// such as code fences, then drops blank and repeated lemmas, keeping the first
    /// meaning given for each.
    private static func words(in reply: String) throws -> [Word] {
        guard let start = reply.firstIndex(of: "["),
              let end = reply.lastIndex(of: "]"),
              start < end,
              let decoded = try? JSONDecoder().decode([Word].self, from: Data(reply[start...end].utf8))
        else { throw ChatError.malformedReply }

        var seen: Set<String> = []
        return decoded.compactMap { word in
            let lemma = word.lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !lemma.isEmpty, seen.insert(lemma).inserted else { return nil }
            return Word(lemma: lemma, meaning: word.meaning.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
