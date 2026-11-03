//
//  Sense.swift
//  VocaGrande
//
//  Created by Troy Mulder on 11/3/26.
//

import SwiftData

/// One meaning of a `Lexeme`: a translation in the learner's native language and a
/// short gloss that tells this meaning apart from the word's others. Spanish banca
/// has several: bank / financial institution, banking / the banking sector,
/// bench / long seat. A lexeme owns its senses, and deleting it deletes them.
///
/// The translation is plain text for now; build plan stage D turns it into a link
/// to a native-language `Lexeme`.
@Model
final class Sense {

    /// The meaning in the native language: "bank".
    var translation: String

    /// A short description of this meaning: "financial institution". Nil when only
    /// the translation is known.
    var gloss: String?

    /// Where this sense sits among the lexeme's senses, first to last.
    var order: Int

    var lexeme: Lexeme?

    init(translation: String, gloss: String? = nil, order: Int) {
        self.translation = translation
        self.gloss = gloss
        self.order = order
    }
}
