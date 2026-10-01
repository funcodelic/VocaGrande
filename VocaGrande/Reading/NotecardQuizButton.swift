//
//  NotecardQuizButton.swift
//  VocaGrande
//
//  Created by Troy Mulder on 10/1/26.
//

import SwiftUI

/// The blue button beside the word count in `LexemeList`. Tapping it presents
/// `NotecardQuizView` as a sheet over the app.
struct NotecardQuizButton: View {

    @Binding var isShowingQuiz: Bool

    var body: some View {
        Button {
            isShowingQuiz = true
        } label: {
            Image(systemName: "rectangle.on.rectangle.angled")
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .controlSize(.small)
        .help("Quiz yourself with notecards")
        .sheet(isPresented: $isShowingQuiz) {
            NotecardQuizView()
        }
    }
}
