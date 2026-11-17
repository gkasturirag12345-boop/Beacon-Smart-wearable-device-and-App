//
//  FallDetectionView.swift
//  BEACON
//
//  Modern Fall Detection Monitoring View
//

import SwiftUI

struct FallDetectionView: View {
    @EnvironmentObject var healthService: HealthMonitoringService
    @State private var currentStatus: FallDetectionEvent?
    @State private var isMonitoring = true
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showEmergencyDialog = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Layout.spacingXLarge) {
                // Hero Status Card
                statusCard

                // Alert Card (if fall detected)
                if let status = currentStatus, !status.resolved {
                    fallAlertCard(status: status)
                }

                // Monitoring Toggle
                monitoringToggleCard

                // How It Works Section
                howItWorksCard

                // Refresh Button
                refreshButton
            }
            .padding(AppTheme.Layout.paddingLarge)
        }
        .background(AppTheme.Colors.groupedBackground)
        .navigationTitle("Fall Detection")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshData()
        }
        .alert("Data Alert", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog("Confirm Status", isPresented: $showEmergencyDialog) {
            Button("I'm OK - Cancel Alert", role: .destructive) {
                acknowledgeCurrentFall()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you're okay? This will cancel the emergency alert.")
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        ModernCard {
            VStack(spacing: AppTheme.Layout.spacingLarge) {
                HStack {
                    Text("Fall Detection")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Spacer()

                    StatusBadge(
                        text: isMonitoring ? "ACTIVE" : "PAUSED",
                        color: isMonitoring ? AppTheme.Colors.success : AppTheme.Colors.textSecondary,
                        style: .filled
                    )
                }

                Divider()

                // Status Circle
                ZStack {
                    // Outer pulsing circle
                    Circle()
                        .fill(isMonitoring ? AppTheme.Colors.success.opacity(0.15) : AppTheme.Colors.textSecondary.opacity(0.1))
                        .frame(width: 140, height: 140)
                        .scaleEffect(isMonitoring ? 1.2 : 1.0)
                        .opacity(isMonitoring ? 0.5 : 1.0)
                        .animation(isMonitoring ? AnimationConfig.pulse : .default, value: isMonitoring)

                    // Middle circle
                    Circle()
                        .stroke(
                            isMonitoring ? AppTheme.Colors.success : AppTheme.Colors.textSecondary,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: isMonitoring ? [] : [10, 5])
                        )
                        .frame(width: 120, height: 120)

                    // Center content
                    VStack(spacing: 8) {
                        Image(systemName: isMonitoring ? "checkmark.shield.fill" : "pause.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(isMonitoring ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)

                        Text(isMonitoring ? "Monitoring" : "Paused")
                            .font(AppTheme.Typography.bodyBold)
                            .foregroundColor(isMonitoring ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
                    }
                }
                .frame(height: 160)

                // Status Message
                Text(isMonitoring ? "System is actively monitoring for falls" : "Fall detection is currently paused")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Fall Alert Card

    private func fallAlertCard(status: FallDetectionEvent) -> some View {
        ModernCard {
            VStack(spacing: AppTheme.Layout.spacingMedium) {
                // Alert Header
                HStack(spacing: AppTheme.Layout.spacingMedium) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.danger.opacity(0.15))
                            .frame(width: 60, height: 60)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(AppTheme.Colors.danger)
                    }
                    .pulseEffect(isActive: true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("FALL DETECTED!")
                            .font(AppTheme.Typography.sectionTitle)
                            .foregroundColor(AppTheme.Colors.danger)

                        Text("Emergency alert active")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    Spacer()
                }

                Divider()

                // Alert Details
                VStack(alignment: .leading, spacing: AppTheme.Layout.spacingSmall) {
                    detailRow(icon: "clock", label: "Time", value: status.timestamp.formatted(date: .omitted, time: .shortened))
                    detailRow(icon: "speedometer", label: "Impact", value: String(format: "%.2f m/s²", status.impactMagnitude))

                    if let location = status.location {
                        detailRow(icon: "location.fill", label: "Location", value: location)
                    }
                }
                .padding(AppTheme.Layout.paddingMedium)
                .background(AppTheme.Colors.danger.opacity(0.05))
                .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

                // I'm OK Button
                ModernButton(
                    title: "I'm OK - Cancel Alert",
                    icon: "person.crop.circle.badge.checkmark",
                    style: .success
                ) {
                    showEmergencyDialog = true
                }
            }
        }
        .glowEffect(isActive: true, color: AppTheme.Colors.danger)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(width: 24)

            Text(label + ":")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(AppTheme.Typography.captionBold)
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }

    // MARK: - Monitoring Toggle Card

    private var monitoringToggleCard: some View {
        ToggleButton(
            title: "Fall Detection Monitoring",
            icon: "figure.fall",
            isOn: $isMonitoring
        )
        .onChange(of: isMonitoring) { oldValue, newValue in
            HapticFeedback.selection()
            // Monitoring state managed by HealthMonitoringService
        }
    }

    // MARK: - How It Works Card

    private var howItWorksCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(AppTheme.Colors.info)
                    Text("How Fall Detection Works")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                    featureRow(
                        icon: "sensor.fill",
                        title: "Accelerometer Monitoring",
                        description: "Continuously analyzes motion data to detect sudden impacts and falls"
                    )

                    featureRow(
                        icon: "bell.badge.fill",
                        title: "Instant Alerts",
                        description: "Sends immediate notifications when a fall is detected"
                    )

                    featureRow(
                        icon: "checkmark.circle.fill",
                        title: "Safety Check",
                        description: "Confirm you're OK or emergency services will be automatically notified"
                    )

                    featureRow(
                        icon: "location.fill",
                        title: "Location Sharing",
                        description: "Your location is shared with emergency contacts when needed"
                    )
                }
            }
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Layout.spacingMedium) {
            Image(systemName: icon)
                .font(.system(size: AppTheme.Layout.iconMedium))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 40, height: 40)
                .background(AppTheme.Colors.primary.opacity(0.15))
                .cornerRadius(AppTheme.Layout.cornerRadiusSmall)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTheme.Typography.bodyBold)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text(description)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Refresh Button

    private var refreshButton: some View {
        ModernButton(
            title: "Refresh Status",
            icon: "arrow.clockwise",
            style: .secondary,
            isLoading: isLoading
        ) {
            refreshData()
        }
    }

    // MARK: - Helper Functions

    private func refreshData() {
        isLoading = true
        HapticFeedback.medium()

        withAnimation(AnimationConfig.smooth) {
            currentStatus = healthService.getFallDetectionStatus()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
    }

    private func acknowledgeCurrentFall() {
        guard let status = currentStatus else { return }

        HapticFeedback.success()

        // Resolve fall alerts
        healthService.activeAlerts.filter { $0.type == .fallDetected }.forEach { alert in
            healthService.resolveAlert(alert.id)
        }

        withAnimation(AnimationConfig.smooth) {
            refreshData()
        }

        alertMessage = "Fall alert cancelled. Stay safe!"
        showAlert = true
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        FallDetectionView()
            .environmentObject(HealthMonitoringService.shared)
    }
}
