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

    /// What the API is doing for this capture, or how its last job ended, if anything.
    let activity: CaptureActivity?

    /// Called to read the text out of the image, or to try again after a failure.
    let onRead: () -> Void

    /// Called to clean the captured text, or to try again after a failure.
    let onClean: () -> Void

    /// Called to translate the cleaned text, or to try again after a failure.
    let onTranslate: () -> Void

    /// Called once the user has confirmed deleting this capture.
    let onDelete: () -> Void

    @State private var stage: CaptureStage

    @State private var isConfirmingDelete = false

    init(
        item: TextSelectionItem,
        image: NSImage?,
        activity: CaptureActivity?,
        onRead: @escaping () -> Void,
        onClean: @escaping () -> Void,
        onTranslate: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.image = image
        self.activity = activity
        self.onRead = onRead
        self.onClean = onClean
        self.onTranslate = onTranslate
        self.onDelete = onDelete
        // An image capture has no text of its own yet, so open on the image.
        _stage = State(initialValue: image == nil ? .original : .image)
    }

    private var hasSelectionText: Bool {
        !(item.selectionText ?? "").isEmpty
    }

    private var hasCleanedText: Bool {
        !(item.cleanedText ?? "").isEmpty
    }

    private var hasTranslatedText: Bool {
        !(item.translatedText ?? "").isEmpty
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
        .onChange(of: activity) { old, _ in
            // Once the image has been read, show what came out of it: the text,
            // or why there isn't any.
            if old == .reading, stage == .image {
                stage = .original
            }
        }
    }

    private var stageButtons: some View {
        HStack(spacing: 10) {
            ForEach(CaptureStage.allCases) { candidate in
                Button {
                    show(candidate)
                } label: {
                    Image(systemName: candidate.symbol)
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(candidate == stage ? Color.blue : Color.secondary)
                .opacity(isDisabled(candidate) ? 0.35 : 1)
                .disabled(isDisabled(candidate))
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

    /// Switches the row to a stage, and starts the work that fills it in when
    /// there is nothing there yet.
    private func show(_ candidate: CaptureStage) {
        stage = candidate
        if candidate == .cleaned, !hasCleanedText, hasSelectionText, activity == nil {
            onClean()
        }
        if candidate == .translated, !hasTranslatedText, hasCleanedText, activity == nil {
            onTranslate()
        }
    }

    /// The text can't be shown while the image is still being read, there is
    /// nothing to clean until there is text, and nothing to translate until it's
    /// been cleaned.
    private func isDisabled(_ candidate: CaptureStage) -> Bool {
        switch candidate {
        case .original: activity == .reading
        case .image: false
        case .cleaned: !hasSelectionText
        case .translated: !hasCleanedText
        }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .original:
            if let selectionText = item.selectionText, !selectionText.isEmpty {
                text(selectionText)
            } else if activity == .reading {
                progress("Reading the image…")
            } else if case .failed(let message)? = activity, image != nil {
                failure(message, retry: onRead)
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
            } else if activity == .cleaning {
                progress("Cleaning…")
            } else if case .failed(let message)? = activity, hasSelectionText {
                failure(message, retry: onClean)
            } else {
                placeholder("Not cleaned yet")
            }
        case .translated:
            if let translatedText = item.translatedText, !translatedText.isEmpty {
                text(translatedText)
            } else if activity == .translating {
                progress("Translating…")
            } else if case .failed(let message)? = activity, hasCleanedText {
                failure(message, retry: onTranslate)
            } else {
                placeholder("Not translated yet")
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

    private func progress(_ string: String) -> some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
            Text(string)
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func failure(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Try again", action: retry)
                .buttonStyle(.link)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    TextSelectionRow(
        item: TextSelectionItem(selectionText: "el sustantivo y el adjetivo"),
        image: nil,
        activity: nil,
        onRead: {},
        onClean: {},
        onTranslate: {},
        onDelete: {}
    )
        .frame(width: 200)
        .padding()
        .modelContainer(for: TextSelectionItem.self, inMemory: true)
}
