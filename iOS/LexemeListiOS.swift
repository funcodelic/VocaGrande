//
//  LexemeListiOS.swift
//  VocaGrande-iOS
//
//  Created by Troy Mulder on 11/1/26.
//

import SwiftData
import SwiftUI

/// The iPhone's root screen, the counterpart of the Mac's `LexemeList` pane: every
/// word saved so far, alphabetically, with a count at the top.
struct LexemeListiOS: View {

    @Query(sort: [SortDescriptor(\Lexeme.lemma, comparator: .localizedStandard)])
    private var lexemes: [Lexeme]

    @State private var isAddingLexeme = false
    @State private var selectedLexeme: Lexeme?

    /// The language listed first: "es" or "en".
    @State private var language = "es"

    /// Words answered correctly at least once in the notecard quiz.
    private var knownCount: Int {
        lexemes.filter { $0.notecardCorrectCount > 0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    languageButton("Spanish", code: "es")
                    languageButton("English", code: "en")

                    Spacer()

                    Button {
                        isAddingLexeme = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(.blue)
                    }
                }

                HStack(spacing: 6) {
                    Text("\(knownCount) words learned")
                        .foregroundStyle(.green)
                    Text("/")
                        .foregroundStyle(.gray)
                    Text("\(lexemes.count) total")
                        .foregroundStyle(.gray)
                }
                .font(.footnote.monospacedDigit())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if lexemes.isEmpty {
                Text("No words yet")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(16)
            } else {
                List(lexemes) { lexeme in
                    Button {
                        selectedLexeme = lexeme
                    } label: {
                        LexemeRowiOS(lexeme: lexeme, language: language)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
        .sheet(isPresented: $isAddingLexeme) {
            LexemeDetailiOS(language: language)
        }
        .sheet(item: $selectedLexeme) { lexeme in
            LexemeDetailiOS(lexeme: lexeme, language: language)
        }
    }

    private func languageButton(_ title: String, code: String) -> some View {
        Button {
            language = code
        } label: {
            Text(title)
                .font(.title3)
                .foregroundStyle(language == code ? Color.blue : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LexemeListiOS()
        .modelContainer(for: [Lexeme.self, TextSelectionItem.self], inMemory: true)
}
