//
//  LexemeRowiOS.swift
//  VocaGrande-iOS
//
//  Created by Troy Mulder on 11/2/26.
//

import SwiftUI

/// One tappable word in the iPhone list. Learned language first: "el gato" (article
/// gray, word in the language's color) then "cat" in white. Native language first:
/// "cat" in the native color, then "el" gray and "gato" white. A chevron sits on the
/// right.
struct LexemeRowiOS: View {

    let lexeme: Lexeme

    /// Whether the native meaning is listed before the word being learned.
    let showsNativeFirst: Bool

    /// The color of the word being learned, shown when it is first.
    let targetColor: Color

    /// The color of the native meaning, shown when it is first.
    let nativeColor: Color

    private var native: String { lexeme.englishMeaning ?? "" }

    private var target: some View {
        HStack(spacing: 8) {
            if let gender = lexeme.gender {
                Text(gender.article(for: lexeme.languageCode))
                    .foregroundStyle(.secondary)
            }
            Text(lexeme.lemma)
                .foregroundStyle(showsNativeFirst ? Color.primary : targetColor)
                .fontWeight(.semibold)
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            if showsNativeFirst {
                Text(native)
                    .fontWeight(.semibold)
                    .foregroundStyle(nativeColor)
                target
            } else {
                target
                Text(native)
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
        LexemeRowiOS(lexeme: Lexeme(lemma: "gato", englishMeaning: "cat", languageCode: "es", gender: .masculine), showsNativeFirst: false, targetColor: .blue, nativeColor: .blue)
        LexemeRowiOS(lexeme: Lexeme(lemma: "gato", englishMeaning: "cat", languageCode: "es", gender: .masculine), showsNativeFirst: true, targetColor: .blue, nativeColor: .orange)
    }
    .padding()
}
