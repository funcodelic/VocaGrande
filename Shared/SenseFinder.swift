//
//  SenseFinder.swift
//  VocaGrande
//
//  Created by Troy Mulder on 11/3/26.
//
//  Asks the model for the meanings of a word that the learner doesn't have yet.

import Foundation

/// Finds a word's meanings. One call serves two uses: "find more meanings" for a word
/// that already has a sense or two (pass them as `known`), and a full lookup from
/// scratch (pass none).
struct SenseFinder {

    /// One meaning the model proposes.
    struct Candidate: Decodable {
        let translation: String
        let gloss: String
    }

    enum Failure: LocalizedError {
        case unreadableReply

        var errorDescription: String? {
            "The meanings came back in a form I couldn't read. Try again."
        }
    }

    /// The most meanings one request may bring back.
    static let limit = 8

    static func instructions(native: String, target: String) -> String {
        """
        You are a bilingual dictionary. You are given a \(target) word and the \
        meanings of it the learner already has. List the other distinct, genuinely \
        common meanings of the \(target) word, as \(native) translations, one entry \
        per meaning. Never repeat a meaning the learner already has, even worded \
        differently. Do not invent meanings; leave out rare, archaic, or purely \
        regional ones. Put the most common first and give at most \(limit). If the \
        learner already has every common meaning, reply with an empty array. \
        Reply with only a JSON array and nothing else, with no code fences. Each \
        element is an object with two string fields: "translation", a short \(native) \
        word or phrase, and "gloss", a description in \(native) of at most eight \
        words, lowercase, with no final period, that tells this meaning apart from \
        the others (for Spanish banca: bank / financial institution; bench / long seat).
        """
    }

    private let service = ChatService()

    /// The meanings of `lemma` not already in `known`, each as (translation, gloss).
    func findSenses(
        lemma: String,
        targetLanguage: String,
        nativeLanguage: String,
        known: [(translation: String, gloss: String?)]
    ) async throws -> [Candidate] {
        let knownLines = known.isEmpty
            ? "(none)"
            : known.map { "- \($0.translation)" + ($0.gloss.map { " / \($0)" } ?? "") }.joined(separator: "\n")

        let reply = try await service.send([
            .developer(Self.instructions(native: nativeLanguage, target: targetLanguage)),
            .user("\(targetLanguage) word: \(lemma)\nMeanings already known:\n\(knownLines)"),
        ])
        return try Self.candidates(in: reply)
    }

    /// Reads the JSON array out of the reply, tolerating stray text or a code fence
    /// around it, and drops any entry with an empty translation.
    static func candidates(in reply: String) throws -> [Candidate] {
        guard let start = reply.firstIndex(of: "["),
              let end = reply.lastIndex(of: "]"),
              start < end,
              let data = String(reply[start...end]).data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Candidate].self, from: data)
        else { throw Failure.unreadableReply }

        return decoded
            .map { Candidate(translation: $0.translation.trimmingCharacters(in: .whitespacesAndNewlines),
                             gloss: $0.gloss.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.translation.isEmpty }
            .prefix(limit)
            .map { $0 }
    }
}
