//
//  LanguageRowiOS.swift
//  VocaGrande-iOS
//
//  Created by Troy Mulder on 11/3/26.
//

#if os(iOS)
import SwiftUI

/// One language in the iPhone's language list: its name in its color, then
/// "50 words learned / 66 total", with a chevron on the right.
struct LanguageRowiOS: View {

    let language: Language

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(language.name)
                    .font(.title2)
                    .foregroundStyle(language.color)

                HStack(spacing: 6) {
                    Text("\(language.learnedCount) words learned")
                        .foregroundStyle(.green)
                    Text("/")
                        .foregroundStyle(.gray)
                    Text("\(language.lexemes.count) total")
                        .foregroundStyle(.gray)
                }
                .font(.footnote.monospacedDigit())
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    LanguageRowiOS(language: Language(code: "es", color: .blue))
        .padding()
}
#endif
