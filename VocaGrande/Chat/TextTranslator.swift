//
//  TextTranslator.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/2/26.
//
//  Translates the cleaned text of a capture into English. The result is the
//  item's `translatedText`.

import Foundation

struct TextTranslator {

    /// The developer message sent ahead of the text. Lives here, with the code
    /// that sends it, rather than as a copy on every item in the store.
    static let instructions = """
    Translate this text into English. It comes from a Spanish textbook, so it is \
    Spanish, or Spanish mixed with some English. Translate the Spanish faithfully and \
    naturally, keeping the author's meaning, tone and sentence order; leave any \
    English as it is. Do not add, drop, summarize, or explain anything. Return only \
    the English translation, with no line breaks.
    """

    private let service = ChatService()

    /// Returns `text` in English.
    func translate(_ text: String) async throws -> String {
        try await service.send([
            .developer(Self.instructions),
            .user(text.trimmingCharacters(in: .whitespacesAndNewlines)),
        ])
    }
}
