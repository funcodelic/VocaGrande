//
//  TextCleaner.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/1/26.
//
//  Cleans the raw text of a capture: spacing, accents and mangled characters
//  fixed, line breaks gone, the author's wording untouched. The result is the
//  item's `cleanedText`.

import Foundation

struct TextCleaner {

    /// The developer message sent ahead of the text. Lives here, with the code
    /// that sends it, rather than as a copy on every item in the store.
    static let instructions = """
    Fix this Spanish text, which was read from a scanned textbook. Correct the \
    spacing, the accents, and any mangled or misread characters. Join the lines into \
    flowing sentences: remove every line break, and rejoin words that were split with \
    a hyphen at the end of a line. Keep the author's words exactly as written, in the \
    same order; do not add, drop, or rephrase anything. Return only the corrected \
    text, with no line breaks.
    """

    private let service = ChatService()

    /// Returns `text` cleaned.
    func clean(_ text: String) async throws -> String {
        try await service.send([
            .developer(Self.instructions),
            .user(text.trimmingCharacters(in: .whitespacesAndNewlines)),
        ])
    }
}
