//
//  LexemeList.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/5/26.
//

import SwiftData
import SwiftUI

/// The pane to the left of the book: every word saved so far, alphabetically,
/// with a count at the top. Words get here by parsing a capture's cleaned text.
struct LexemeList: View {

    @Query(sort: [SortDescriptor(\Lexeme.lemma, comparator: .localizedStandard)])
    private var lexemes: [Lexeme]

    @State private var isShowingQuiz = false

    /// Words answered correctly at least once in the notecard quiz.
    private var knownCount: Int {
        lexemes.filter { $0.notecardCorrectCount > 0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Vocabulary")
                    .font(.headline)

                Spacer()

                NotecardQuizButton(isShowingQuiz: $isShowingQuiz)

                HStack(spacing: 3) {
                    Text("\(knownCount)")
                        .foregroundStyle(.green)
                    Text("/ \(lexemes.count)")
                        .foregroundStyle(.gray)
                }
                .font(.callout.monospacedDigit())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if lexemes.isEmpty {
                Text("No words yet")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(12)
            } else {
                List(lexemes) { lexeme in
                    LexemeRow(lexeme: lexeme, style: .prominent)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

#Preview {
    LexemeList()
        .frame(width: 220, height: 800)
        .modelContainer(for: Lexeme.self, inMemory: true)
}
