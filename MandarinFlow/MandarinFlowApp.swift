//
//  MandarinFlowApp.swift
//  MandarinFlow
//
//  Created by Ava Zhou on 2026/7/10.
//

import AppKit
import SwiftUI
import SwiftData
import UserNotifications

// Lets macOS present scheduled review reminders as native banners while the app is active.
final class MandarinFlowAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

// Configures the app window and injects the shared local SwiftData container.
@main
struct MandarinFlowApp: App {
    @NSApplicationDelegateAdaptor(MandarinFlowAppDelegate.self) private var appDelegate

    // Shared SwiftData container for app-wide local persistence.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            DictationSet.self,
            VocabularyWord.self,
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
            NavigationStack {
                ContentView()
            }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1180, height: 720)
        .windowStyle(.hiddenTitleBar)
    }
}
