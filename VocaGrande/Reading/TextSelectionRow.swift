//
//  TextSelectionRow.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/1/26.
//

import SwiftUI

/// One captured selection, as a row in the sidebar's list. The buttons across the
/// top pick which stage of the capture the row shows.
struct TextSelectionRow: View {

    /// How tall a row's content is. Anything taller — a long selection, a tall
    /// image — scrolls within it rather than stretching the row.
    private static let contentHeight: CGFloat = 80

    let selection: TextSelection

    @State private var stage: CaptureStage

    init(selection: TextSelection) {
        self.selection = selection
        // An image capture has no text of its own yet, so open on the image.
        _stage = State(initialValue: selection.selectedImage == nil ? .original : .image)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            stageButtons

            ScrollView(.vertical) {
                content
            }
            .frame(height: Self.contentHeight)
        }
        .padding(.vertical, 4)
    }

    private var stageButtons: some View {
        HStack(spacing: 10) {
            ForEach(CaptureStage.allCases) { candidate in
                Button {
                    stage = candidate
                } label: {
                    Image(systemName: candidate.symbol)
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(candidate == stage ? Color.blue : Color.secondary)
                .help(candidate.label)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .original:
            if selection.text.isEmpty {
                placeholder("No text captured")
            } else {
                text(selection.text)
            }
        case .image:
            if let image = selection.selectedImage {
                image
                    .resizable()
                    .scaledToFit()
            } else {
                placeholder("No image captured")
            }
        case .cleaned:
            if selection.cleanedText.isEmpty {
                placeholder("Not cleaned yet")
            } else {
                text(selection.cleanedText)
            }
        }
    }

    private func text(_ string: String) -> some View {
        Text(string)
            .font(.callout)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func placeholder(_ string: String) -> some View {
        Text(string)
            .font(.callout)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    TextSelectionRow(selection: TextSelection(text: "el sustantivo y el adjetivo"))
        .frame(width: 200)
        .padding()
}
