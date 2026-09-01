//
//  SidebarView.swift
//  VocaGrande
//
//  Created by Troy Mulder on 8/31/26.
//

import SwiftUI

/// The pane to the right of the book. Lists the text captured out of the
/// document, and offers the `+` that captures the current selection.
struct SidebarView: View {

    let controller: BookPdfController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    controller.captureSelection()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .foregroundStyle(controller.selectedText == nil ? Color.secondary : Color.blue)
                .help("Select text to capture")

                Button {
                    controller.toggleAreaSelectionMode()
                } label: {
                    Image(systemName: "rectangle.dashed")
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .foregroundStyle(controller.isAreaSelectionMode ? Color.blue : Color.secondary)
                .help("Drag a rectangle on the page to capture it as an image")

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            List(controller.textSelections) { selection in
                TextSelectionRow(selection: selection)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

#Preview {
    SidebarView(controller: BookPdfController())
        .frame(width: 200, height: 800)
}
