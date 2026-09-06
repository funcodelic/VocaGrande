//
//  LexemeRow.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/5/26.
//

import SwiftData
import SwiftUI

/// One word on one line: the lemma, then its English meaning. Used both in the
/// `LexemeList` pane and inside a capture's row for the words parsed out of it.
struct LexemeRow: View {

    /// How the row is drawn: small and on one line inside a capture's row, or
    /// larger and colored in the `LexemeList` pane, where a long meaning may wrap.
    enum Style {
        case compact
        case prominent
    }

    let lexeme: Lexeme

    var style: Style = .compact

    private var font: Font {
        switch style {
        case .compact: .callout
        case .prominent: .title3
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(lexeme.lemma)
                .font(font.weight(.semibold))
                .foregroundStyle(style == .prominent ? Color.blue : Color.primary)

            if let meaning = lexeme.englishMeaning, !meaning.isEmpty {
                Text(meaning)
                    .font(font)
                    .foregroundStyle(style == .prominent ? Color.primary : Color.secondary)
            } else {
                Text("not translated")
                    .font(font)
                    .foregroundStyle(.tertiary)
            }
        }
        .lineLimit(style == .compact ? 1 : nil)
        .truncationMode(.tail)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 4) {
        LexemeRow(lexeme: Lexeme(lemma: "comer", englishMeaning: "to eat", languageCode: "es"))
        LexemeRow(lexeme: Lexeme(lemma: "casa", languageCode: "es"))
        LexemeRow(lexeme: Lexeme(lemma: "comer", englishMeaning: "to eat", languageCode: "es"), style: .prominent)
        LexemeRow(lexeme: Lexeme(lemma: "casa", languageCode: "es"), style: .prominent)
    }
    .padding()
    .frame(width: 220)
    .modelContainer(for: Lexeme.self, inMemory: true)
}
