//
//  Language.swift
//  VocaGrande
//
//  Created by Troy Mulder on 11/3/26.
//

import SwiftData
import SwiftUI

/// The UserDefaults keys for the one-only profile settings. UserDefaults is the
/// app's writable property list; the bundled Info.plist is read-only at runtime.
enum ProfileKeys {

    /// The code of the learner's native language: "en".
    static let nativeLanguage = "nativeLanguage"

    /// The `LanguageColor` raw value chosen for the native language.
    static let nativeLanguageColor = "nativeLanguageColor"
}

/// The main colors a learner can give a language.
enum LanguageColor: String, CaseIterable {
    case red, orange, yellow, green, teal, blue, purple, pink

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .teal: .teal
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        }
    }

    /// The order colors are handed out in when none is picked: blue first.
    static let defaultOrder: [LanguageColor] = [.blue, .orange, .green, .red, .purple, .teal, .pink, .yellow]
}

/// A language the learner is studying. It owns every lexeme in that language, so
/// deleting a language deletes its words.
@Model
final class Language {

    /// The language's code: "es". One `Language` per code.
    @Attribute(.unique) var code: String

    /// The `LanguageColor` raw value this language is shown in.
    var colorName: String

    /// When the language was added; the list shows them in this order.
    var dateAdded: Date

    @Relationship(deleteRule: .cascade, inverse: \Lexeme.language) var lexemes: [Lexeme] = []

    init(code: String, color: LanguageColor = .blue, dateAdded: Date = .now) {
        self.code = code
        self.colorName = color.rawValue
        self.dateAdded = dateAdded
    }

    var name: String { AppLanguage.name(forCode: code) }

    var color: Color { (LanguageColor(rawValue: colorName) ?? .blue).color }

    /// Words answered correctly at least once in the notecard quiz.
    var learnedCount: Int {
        lexemes.filter { $0.notecardCorrectCount > 0 }.count
    }

    /// Lexemes saved before languages existed have no `Language`. Gives each one a
    /// `Language` for its `languageCode`, creating the language if needed, so no
    /// existing word is stranded.
    static func adoptOrphans(in context: ModelContext) {
        guard let lexemes = try? context.fetch(FetchDescriptor<Lexeme>()) else { return }
        let orphans = lexemes.filter { $0.language == nil }
        guard !orphans.isEmpty else { return }

        let existing = (try? context.fetch(FetchDescriptor<Language>())) ?? []
        var byCode = Dictionary(existing.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })

        for lexeme in orphans {
            if byCode[lexeme.languageCode] == nil {
                let used = Set(byCode.values.map(\.colorName))
                let color = LanguageColor.defaultOrder.first { !used.contains($0.rawValue) } ?? .blue
                let language = Language(code: lexeme.languageCode, color: color)
                context.insert(language)
                byCode[language.code] = language
            }
            lexeme.language = byCode[lexeme.languageCode]
        }
    }
}
