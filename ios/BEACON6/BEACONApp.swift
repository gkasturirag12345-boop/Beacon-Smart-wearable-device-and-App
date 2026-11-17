//
//  BEACONApp.swift
//  BEACON
//
//  Created by Kasturiraj Guhan on 2/10/25.
//

import SwiftUI

@main
struct BEACONApp: App {
    // Initialize services on app launch
    init() {
        // Initialize settings manager first
        _ = SettingsManager.shared

        // Request notification authorization
        Task {
            await NotificationService.shared.requestAuthorization()
        }
        // Setup notification categories
        NotificationService.shared.setupNotificationCategories()

        // Initialize health monitoring service (auto-starts SOS detection)
        _ = HealthMonitoringService.shared
        print("[BEACONApp] ✅ HealthMonitoringService initialized - SOS detection starting...")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .ignoresSafeArea(.keyboard) // Only ignore keyboard, not screen edges
        }
    }
}
