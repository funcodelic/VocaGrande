//
//  LexemeListiOS.swift
//  VocaGrande-iOS
//
//  Created by Troy Mulder on 11/1/26.
//

import SwiftData
import SwiftUI

/// The words of one language, alphabetically, with a count at the top. Opened from
/// `LanguageListViewiOS`; the language's words translate to the native language
/// saved in the profile.
struct LexemeListiOS: View {

    let language: Language

    @Environment(\.modelContext) private var modelContext

    @AppStorage(ProfileKeys.nativeLanguage) private var nativeCode = ""
    @AppStorage(ProfileKeys.nativeLanguageColor) private var nativeColorName = ""

    @State private var isAddingLexeme = false
    @State private var selectedLexeme: Lexeme?
    @State private var lexemePendingDelete: Lexeme?

    /// Whether the native language is listed first, rather than the one being learned.
    @State private var showsNativeFirst = false

    private var lexemes: [Lexeme] {
        language.lexemes.sorted { $0.lemma.localizedStandardCompare($1.lemma) == .orderedAscending }
    }

    private var nativeName: String {
        nativeCode.isEmpty ? "Native" : AppLanguage.name(forCode: nativeCode)
    }

    private var nativeColor: Color {
        (LanguageColor(rawValue: nativeColorName) ?? .blue).color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("\(language.learnedCount) words learned")
                    .foregroundStyle(.green)
                Text("/")
                    .foregroundStyle(.gray)
                Text("\(language.lexemes.count) total")
                    .foregroundStyle(.gray)
            }
            .font(.footnote.monospacedDigit())
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            Divider()

            if language.lexemes.isEmpty {
                Text("No words yet")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(16)
            } else {
                List(lexemes) { lexeme in
                    Button {
                        selectedLexeme = lexeme
                    } label: {
                        LexemeRowiOS(
                            lexeme: lexeme,
                            showsNativeFirst: showsNativeFirst,
                            targetColor: language.color,
                            nativeColor: nativeColor
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            lexemePendingDelete = lexeme
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 16) {
                    languageButton(language.name, color: language.color, isNative: false)
                    languageButton(nativeName, color: nativeColor, isNative: true)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingLexeme = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(showsNativeFirst ? nativeColor : language.color)
                }
            }
        }
        .sheet(isPresented: $isAddingLexeme) {
            LexemeDetailiOS(language: language, showsNativeFirst: showsNativeFirst)
        }
        .sheet(item: $selectedLexeme) { lexeme in
            LexemeDetailiOS(lexeme: lexeme, language: language, showsNativeFirst: showsNativeFirst)
        }
        .alert(
            "Delete Word",
            isPresented: Binding(
                get: { lexemePendingDelete != nil },
                set: { if !$0 { lexemePendingDelete = nil } }
            ),
            presenting: lexemePendingDelete
        ) { lexeme in
            Button("Delete", role: .destructive) {
                modelContext.delete(lexeme)
            }
            Button("Cancel", role: .cancel) {}
        } message: { lexeme in
            Text("Are you sure you want to delete \(lexeme.lemma)?")
        }
    }

    private func languageButton(_ title: String, color: Color, isNative: Bool) -> some View {
        Button {
            showsNativeFirst = isNative
        } label: {
            Text(title)
                .font(.title2.weight(.medium))
                .foregroundStyle(showsNativeFirst == isNative ? color : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LexemeListiOS(language: Language(code: "es", color: .blue))
        .modelContainer(for: [Language.self, Lexeme.self, TextSelectionItem.self], inMemory: true)
}
