//
//  AppLanguage.swift
//  VocaGrande
//
//  Created by Troy Mulder on 11/3/26.
//

import Foundation

/// A language the app knows about: a two-letter code and its English name. This is
/// the fixed catalog the language picker offers; what a learner has actually added
/// lives in `Language`.
struct AppLanguage: Identifiable, Hashable {

    /// ISO 639-1 code: "es" for Spanish.
    let code: String

    let name: String

    var id: String { code }

    /// The most commonly studied languages, listed first in the picker.
    private static let popularCodes = ["en", "es", "fr", "de", "it", "pt"]

    /// Every selectable language: the popular ones first, then the rest alphabetically.
    static let all: [AppLanguage] = catalog.filter { popularCodes.contains($0.code) }
        .sorted { popularCodes.firstIndex(of: $0.code)! < popularCodes.firstIndex(of: $1.code)! }
        + catalog.filter { !popularCodes.contains($0.code) }

    /// Every language, alphabetical by name.
    private static let catalog: [AppLanguage] = [
        ("ar", "Arabic"), ("zh", "Chinese"), ("cs", "Czech"), ("da", "Danish"),
        ("nl", "Dutch"), ("en", "English"), ("fi", "Finnish"), ("fr", "French"),
        ("de", "German"), ("el", "Greek"), ("he", "Hebrew"), ("hi", "Hindi"),
        ("hu", "Hungarian"), ("id", "Indonesian"), ("it", "Italian"), ("ja", "Japanese"),
        ("ko", "Korean"), ("no", "Norwegian"), ("pl", "Polish"), ("pt", "Portuguese"),
        ("ro", "Romanian"), ("ru", "Russian"), ("es", "Spanish"), ("sv", "Swedish"),
        ("th", "Thai"), ("tr", "Turkish"), ("uk", "Ukrainian"), ("vi", "Vietnamese"),
    ].map { AppLanguage(code: $0.0, name: $0.1) }

    /// Letters a learner of the language is likely to need and an English keyboard
    /// makes awkward to type, for the strip above the keyboard. Empty for languages
    /// that don't need any.
    static func specialCharacters(forCode code: String) -> [String] {
        switch code {
        case "es": ["á", "é", "í", "ó", "ú", "ü", "ñ", "¿", "¡"]
        case "it": ["à", "è", "é", "ì", "ò", "ù"]
        case "fr": ["à", "â", "ç", "é", "è", "ê", "ë", "î", "ï", "ô", "ù", "û", "œ"]
        case "pt": ["á", "à", "â", "ã", "ç", "é", "ê", "í", "ó", "ô", "õ", "ú"]
        case "de": ["ä", "ö", "ü", "ß"]
        default: []
        }
    }

    /// The English name for a code, or the uppercased code when it isn't in the catalog.
    static func name(forCode code: String) -> String {
        all.first { $0.code == code }?.name ?? code.uppercased()
    }
}
