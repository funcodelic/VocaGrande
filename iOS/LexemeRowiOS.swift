//
//  LexemeRowiOS.swift
//  VocaGrande-iOS
//
//  Created by Troy Mulder on 11/2/26.
//

import SwiftUI

/// One tappable word in the iPhone list. Spanish selected: "el gato" (article gray,
/// word blue) then "cat" in white. English selected: "cat" in blue, then "el"
/// gray and "gato" white. A chevron sits on the right.
struct LexemeRowiOS: View {

    let lexeme: Lexeme

    /// The language shown first: "es" or "en".
    let language: String

    private var english: String { lexeme.englishMeaning ?? "" }

    private var spanish: some View {
        HStack(spacing: 8) {
            if let gender = lexeme.gender {
                Text(gender.article)
                    .foregroundStyle(.secondary)
            }
            Text(lexeme.lemma)
                .foregroundStyle(language == "en" ? Color.primary : Color.blue)
                .fontWeight(.semibold)
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            if language == "en" {
                Text(english)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.blue)
                spanish
            } else {
                spanish
                Text(english)
                    .foregroundStyle(Color.primary)
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .font(.title3)
        .lineLimit(1)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack {
        LexemeRowiOS(lexeme: Lexeme(lemma: "gato", englishMeaning: "cat", languageCode: "es", gender: .masculine), language: "es")
        LexemeRowiOS(lexeme: Lexeme(lemma: "gato", englishMeaning: "cat", languageCode: "es", gender: .masculine), language: "en")
    }
    .padding()
}
