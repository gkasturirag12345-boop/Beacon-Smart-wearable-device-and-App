//
//  DashboardView.swift
//  BEACON
//
//  Modern dashboard with card-based layout
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var healthService: HealthMonitoringService
    @StateObject private var locationService = LocationService.shared

    @State private var currentHeartRate: HeartRateData?
    @State private var fallStatus: FallDetectionEvent?
    @State private var isMonitoring = true
    @State private var showingLocationMap = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Layout.spacingXLarge) {
                    // Hero Section
                    heroSection

                    // Main Metrics
                    heartRateSection

                    // Status Grid
                    statusGrid

                    // Recent Activity
                    recentActivitySection

                    // Quick Actions
                    quickActionsSection
                }
                .padding(AppTheme.Layout.paddingLarge)
            }
            .background(AppTheme.Colors.groupedBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("BEACON")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.primary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    ConnectionStatusBadge(
                        mode: connectionMode,
                        isConnected: healthService.isConnected
                    )
                }
            }
            .refreshable {
                await refreshData()
            }
            .onAppear {
                Task {
                    await refreshData()
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Layout.spacingSmall) {
            Text("Health Dashboard")
                .font(AppTheme.Typography.heroTitle)
                .foregroundColor(AppTheme.Colors.textPrimary)

            HStack(spacing: AppTheme.Layout.spacingSmall) {
                LiveDataIndicator(isLive: healthService.isConnected)

                Text(healthService.isConnected ? "Monitoring active" : "Device offline")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Heart Rate Section

    private var heartRateSection: some View {
        ModernCard {
            if let hr = currentHeartRate {
                VStack(spacing: AppTheme.Layout.spacingLarge) {
                    AnimatedHeartRate(
                        heartRate: Int(hr.bpm),
                        isAnimating: healthService.isConnected
                    )

                    HStack {
                        HeartRateZoneBadge(heartRate: Int(hr.bpm))

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Updated")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            Text(hr.timestamp, style: .relative)
                                .font(AppTheme.Typography.captionBold)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
            } else {
                EmptyStateView(
                    icon: "heart.slash",
                    title: "No Heart Rate Data",
                    message: "Connect your device to start monitoring",
                    actionTitle: nil,
                    action: nil
                )
                .frame(height: 200)
            }
        }
    }

    // MARK: - Status Grid

    private var statusGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: AppTheme.Layout.spacingMedium),
                GridItem(.flexible(), spacing: AppTheme.Layout.spacingMedium)
            ],
            spacing: AppTheme.Layout.spacingMedium
        ) {
            // Fall Detection Card
            InfoCard(
                icon: "figure.fall",
                iconColor: isMonitoring ? AppTheme.Colors.success : AppTheme.Colors.textSecondary,
                title: "Fall Detection",
                value: isMonitoring ? "Active" : "Paused",
                subtitle: fallStatus != nil && !fallStatus!.resolved ? "Alert active" : nil
            )

            // Device Status Card
            InfoCard(
                icon: "applewatch",
                iconColor: healthService.isConnected ? AppTheme.Colors.bluetooth : AppTheme.Colors.textSecondary,
                title: "Device",
                value: healthService.isConnected ? "Connected" : "Offline",
                subtitle: healthService.isConnected ? "Ready" : "Searching..."
            )

            // Wear Status Card
            InfoCard(
                icon: "figure.walk",
                iconColor: healthService.currentWearStatus == .worn ? AppTheme.Colors.success : AppTheme.Colors.warning,
                title: "Wear Status",
                value: wearStatusText,
                subtitle: nil
            )

            // Network Mode Card
            InfoCard(
                icon: connectionMode.iconName,
                iconColor: networkModeColor,
                title: "Connection",
                value: connectionMode.displayName,
                subtitle: nil
            )
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
            Text("Recent Activity")
                .font(AppTheme.Typography.sectionTitle)
                .foregroundColor(AppTheme.Colors.textPrimary)

            ModernCard(padding: 0) {
                VStack(spacing: 0) {
                    if let hr = currentHeartRate {
                        activityRow(
                            icon: "heart.fill",
                            iconColor: AppTheme.Colors.heartRate,
                            title: "Heart Rate Monitored",
                            subtitle: "\(Int(hr.bpm)) BPM",
                            timestamp: hr.timestamp
                        )

                        Divider()
                            .padding(.leading, 70)
                    }

                    if fallStatus == nil {
                        activityRow(
                            icon: "checkmark.shield.fill",
                            iconColor: AppTheme.Colors.success,
                            title: "No Falls Detected",
                            subtitle: "System monitoring active",
                            timestamp: Date()
                        )
                    } else if let fall = fallStatus, !fall.resolved {
                        activityRow(
                            icon: "exclamationmark.triangle.fill",
                            iconColor: AppTheme.Colors.danger,
                            title: "Fall Detected",
                            subtitle: "Requires attention",
                            timestamp: fall.timestamp
                        )
                    }
                }
            }
        }
    }

    private func activityRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        timestamp: Date
    ) -> some View {
        HStack(spacing: AppTheme.Layout.spacingMedium) {
            Image(systemName: icon)
                .font(.system(size: AppTheme.Layout.iconMedium))
                .foregroundColor(iconColor)
                .frame(width: 50, height: 50)
                .background(iconColor.opacity(0.15))
                .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTheme.Typography.bodyBold)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()

            Text(timestamp, style: .relative)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding(AppTheme.Layout.paddingLarge)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
            Text("Quick Actions")
                .font(AppTheme.Typography.sectionTitle)
                .foregroundColor(AppTheme.Colors.textPrimary)

            VStack(spacing: AppTheme.Layout.spacingMedium) {
                NavigationLink(destination: HeartRateView()) {
                    quickActionButton(
                        icon: "heart.fill",
                        title: "View Heart Rate Details",
                        color: AppTheme.Colors.heartRate
                    )
                }
                .buttonStyle(PlainButtonStyle())

                NavigationLink(destination: FallDetectionView()) {
                    quickActionButton(
                        icon: "figure.fall",
                        title: "Fall Detection Settings",
                        color: .orange
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: openLocationInMaps) {
                    quickActionButton(
                        icon: "map.fill",
                        title: "Locate Device on Map",
                        color: .blue
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func quickActionButton(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: AppTheme.Layout.spacingMedium) {
            Image(systemName: icon)
                .font(.system(size: AppTheme.Layout.iconMedium))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15))
                .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

            Text(title)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding(AppTheme.Layout.paddingLarge)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.Layout.cornerRadiusLarge)
        .shadow(
            color: AppTheme.Shadows.small.color,
            radius: AppTheme.Shadows.small.radius,
            x: AppTheme.Shadows.small.x,
            y: AppTheme.Shadows.small.y
        )
    }

    // MARK: - Helper Functions

    private func refreshData() async {
        withAnimation(AnimationConfig.smooth) {
            currentHeartRate = healthService.getCurrentHeartRate()
            fallStatus = healthService.getFallDetectionStatus()
        }
    }

    private func openLocationInMaps() {
        HapticFeedback.medium()
        locationService.getCurrentLocation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            locationService.openInAppleMaps()
        }
    }

    private var wearStatusText: String {
        switch healthService.currentWearStatus {
        case .worn: return "Worn"
        case .notWorn: return "Not Worn"
        case .unknown: return "Unknown"
        }
    }

    private var connectionMode: ConnectionMode {
        ConnectionMode.current(isConnected: healthService.isConnected)
    }

    private var networkModeColor: Color {
        switch connectionMode {
        case .ble: return AppTheme.Colors.bluetooth
        case .offline: return AppTheme.Colors.textSecondary
        }
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(HealthMonitoringService.shared)
}
