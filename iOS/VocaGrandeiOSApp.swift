//
//  VocaGrandeiOSApp.swift
//  VocaGrande-iOS
//
//  Created by Troy Mulder on 11/1/26.
//

import SwiftData
import SwiftUI

@main
struct VocaGrandeiOSApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TextSelectionItem.self,
            Lexeme.self,
            Language.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            LanguageListViewiOS()
        }
        .modelContainer(sharedModelContainer)
    }
}
