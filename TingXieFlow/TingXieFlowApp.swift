//
//  TingXieFlowApp.swift
//  TingXieFlow
//
//  Created by Ava Zhou on 2026/7/10.
//

import SwiftUI
import SwiftData

@main
struct TingXieFlowApp: App {
    // Shared SwiftData container for app-wide local persistence.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
