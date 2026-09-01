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
// - cleanedText, translatedText and the prompts belong to later stages.

/// One piece of text captured out of the book, persisted with SwiftData.
@Model
final class TextSelectionItem {

    /// When this selection was captured.
    var captureTime: Date

    /// The original, raw text: what was selected in the book, or later, what was read
    /// out of the captured image. Nil until one of those has happened.
    var selectionText: String?

    /// The cleaned text: spacing, accents and mangled characters fixed, the author's
    /// wording untouched. Nil until it has been cleaned.
    var cleanedText: String?

    /// The prompt used to turn selectionText, or the image, into cleanedText.
    /// Starts as `defaultCleanPrompt`; the UI will let the user change it.
    var cleanPrompt: String

    /// The translated text, for later.
    var translatedText: String?

    /// The prompt used to translate, for later.
    var translationPrompt: String

    /// The language to translate into, for later.
    var translationLanguage: String

    static let defaultCleanPrompt = """
        Fix the spacing, accents, and mangled characters in this Spanish text, which was \
        read from a scanned textbook. Keep the author's wording exactly. Return only the \
        corrected text.
        """

    static let defaultTranslationPrompt = """
        Translate this Spanish text into natural English. Return only the translation.
        """

    /// A text capture passes `selectionText`; an image capture passes nothing and
    /// gets its text later.
    init(selectionText: String? = nil, captureTime: Date = .now) {
        self.captureTime = captureTime
        self.selectionText = selectionText
        self.cleanedText = nil
        self.cleanPrompt = Self.defaultCleanPrompt
        self.translatedText = nil
        self.translationPrompt = Self.defaultTranslationPrompt
        self.translationLanguage = "English"
    }
}
