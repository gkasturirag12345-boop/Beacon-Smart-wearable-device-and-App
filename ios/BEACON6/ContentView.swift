//
//  ContentView.swift
//  BEACON
//
//  Created by Kasturiraj Guhan on 2/10/25.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @StateObject private var healthService = HealthMonitoringService.shared
    @StateObject private var notificationService = NotificationService.shared
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            // Main tab view
            TabView(selection: $selectedTab) {
            // Dashboard
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)
                .badge(getConnectionBadge())

            // Heart Rate
            HeartRateView()
                .tabItem {
                    Label("Heart Rate", systemImage: "heart.fill")
                }
                .tag(1)

            // Fall Detection
            FallDetectionView()
                .tabItem {
                    Label("Fall Detection", systemImage: "figure.fall")
                }
                .tag(2)

            // Test Mode (for development)
            TestModeView()
                .tabItem {
                    Label("Test Mode", systemImage: "testtube.2")
                }
                .tag(4)

            // Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(5)

            // BLE Connection
            BLEConnectionView(bleManager: healthService.bleManager)
                .tabItem {
                    Label("Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(6)

            // Debug Status (NEW)
            DebugStatusView()
                .tabItem {
                    Label("Debug", systemImage: "ladybug")
                }
                .tag(7)
            }
            .environmentObject(healthService)
            .onAppear {
                setupNotifications()
            }

            // SOS Alert Banner Overlay (appears on top of all tabs)
            if healthService.showSOSBanner {
                AlertBannerView(
                    message: healthService.sosAlertMessage,
                    confidence: healthService.sosAlertConfidence,
                    detectionTime: healthService.sosDetectionTime,
                    latencyMs: healthService.sosLatencyMs,
                    isPresented: $healthService.showSOSBanner
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999) // Ensure it's on top
            }
        }
    }

    private func getConnectionBadge() -> String {
        switch ConnectionMode.current(isConnected: healthService.isConnected) {
        case .ble:
            return "BLE"
        case .offline:
            return "!"
        }
    }

    private func setupNotifications() {
        Task {
            let granted = await notificationService.requestAuthorization()
            if granted {
                notificationService.setupNotificationCategories()
            }
        }
    }
}

// DashboardView is now in its own file: Views/DashboardView.swift

#Preview {
    ContentView()
}
