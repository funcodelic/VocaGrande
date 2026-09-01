//
//  TextSelectionRow.swift
//  VocaGrande
//
//  Created by Troy Mulder on 9/1/26.
//

import SwiftData
import SwiftUI

/// One captured selection, as a row in the sidebar's list. The buttons across the
/// top pick which stage of the capture the row shows; the one at the far right
/// deletes the capture after asking.
struct TextSelectionRow: View {

    /// How tall a row's content is. Anything taller — a long selection, a tall
    /// image — scrolls within it rather than stretching the row.
    private static let contentHeight: CGFloat = 80

    let item: TextSelectionItem

    /// The image this capture was dragged as, if it was and it's still this session.
    let image: NSImage?

    /// Called once the user has confirmed deleting this capture.
    let onDelete: () -> Void

    @State private var stage: CaptureStage

    @State private var isConfirmingDelete = false

    init(item: TextSelectionItem, image: NSImage?, onDelete: @escaping () -> Void) {
        self.item = item
        self.image = image
        self.onDelete = onDelete
        // An image capture has no text of its own yet, so open on the image.
        _stage = State(initialValue: image == nil ? .original : .image)
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

            Spacer()

            Button {
                isConfirmingDelete = true
            } label: {
                Image(systemName: "trash")
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.secondary)
            .help("Delete this capture")
        }
        .alert("Delete this item?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .original:
            if let selectionText = item.selectionText, !selectionText.isEmpty {
                text(selectionText)
            } else {
                placeholder("No text captured")
            }
        case .image:
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                placeholder("No image captured")
            }
        case .cleaned:
            if let cleanedText = item.cleanedText, !cleanedText.isEmpty {
                text(cleanedText)
            } else {
                placeholder("Not cleaned yet")
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
    TextSelectionRow(
        item: TextSelectionItem(selectionText: "el sustantivo y el adjetivo"),
        image: nil,
        onDelete: {}
    )
        .frame(width: 200)
        .padding()
        .modelContainer(for: TextSelectionItem.self, inMemory: true)
}
