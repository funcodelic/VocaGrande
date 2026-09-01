//
//  VocaGrandeApp.swift
//  VocaGrande
//
//  Created by Troy Mulder on 8/16/26.
//

import AppKit
import SwiftUI
import SwiftData

/// Quits VocaGrande when its last window is closed, rather than leaving the app
/// running with no windows the way macOS does by default.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct VocaGrandeApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TextSelectionItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var bookController = BookPdfController()

    var body: some Scene {
        WindowGroup {
            BookPdfView(controller: bookController)
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Zoom In") { bookController.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") { bookController.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)

                Button("Fit to Window") { bookController.fitToWindow() }
                    .keyboardShortcut("0", modifiers: .command)

                Divider()
            }
        }
    }
}
