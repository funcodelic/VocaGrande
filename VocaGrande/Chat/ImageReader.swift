//
//  ImageReader.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/1/26.
//
//  Reads the text out of an image captured from the book: the API's transcription
//  of what is printed there, and nothing else. What comes back is the raw
//  `selectionText`; fixing it up is `TextCleaner`'s job.

import AppKit

struct ImageReader {

    /// The developer message sent ahead of the image. Fixed for now; the clean
    /// prompt already lives on the item, and this one can join it there later.
    static let instructions = """
    You transcribe Spanish text from images of pages in a printed textbook.

    Write out exactly the text that appears in the image, in reading order, with \
    the author's words, spelling, accents, punctuation and capitalization as \
    printed. Keep the line breaks where the printed lines break. Leave out page \
    numbers, running headers and footers, and anything that is not text.

    Do not translate, correct, summarize, or complete anything. If part of the \
    image is unreadable, write [ilegible] in its place.

    Reply with the transcription and nothing else: no preamble, no commentary, \
    no code fences.
    """

    private let service = ChatService()

    /// Returns the text printed in the image.
    func read(_ image: NSImage) async throws -> String {
        try await service.send([
            .developer(Self.instructions),
            .user("Transcribe the text in this image.", image: image),
        ])
    }
}
