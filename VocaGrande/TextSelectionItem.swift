//
//  TextSelectionItem.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/1/26.
//

import Foundation
import SwiftData

// Rules
// - Save text only. An image is transitory: `BookPdfController` holds it for this
//   session, keyed by the item's persistentModelID, and it is never written to the store.
// - A capture made by selecting text stores it in selectionText.
// - A capture made from an image starts with selectionText nil. Later the image is
//   read to fill in selectionText with the raw, uncleaned text.
// - cleanedText and translatedText belong to later stages.
// - The prompts that produce them are not stored here. They live with the code that
//   sends them, in the Chat folder: `ImageReader.instructions`, `TextCleaner.instructions`.

/// One piece of text captured out of the book, persisted with SwiftData.
@Model
final class TextSelectionItem {

    /// When this selection was captured.
    var captureTime: Date

    /// The original, raw text: what was selected in the book, or later, what was read
    /// out of the captured image. Nil until one of those has happened.
    var selectionText: String?

    /// The cleaned text: spacing, accents and mangled characters fixed, line breaks
    /// gone, the author's wording untouched. Nil until it has been cleaned.
    var cleanedText: String?

    /// The translated text, for later.
    var translatedText: String?

    /// A text capture passes `selectionText`; an image capture passes nothing and
    /// gets its text later.
    init(selectionText: String? = nil, captureTime: Date = .now) {
        self.captureTime = captureTime
        self.selectionText = selectionText
        self.cleanedText = nil
        self.translatedText = nil
    }
}
