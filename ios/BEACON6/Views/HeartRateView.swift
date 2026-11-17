//
//  HeartRateView.swift
//  BEACON
//
//  Modern Heart Rate Monitoring View
//

import SwiftUI
import Charts

struct HeartRateView: View {
    @EnvironmentObject var healthService: HealthMonitoringService
    @State private var currentHeartRate: HeartRateData?
    @State private var heartRateHistory: [HeartRateData] = []
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Layout.spacingXLarge) {
                // Hero Heart Rate Display
                heroHeartRateCard

                // Heart Rate Chart
                if #available(iOS 16.0, *) {
                    chartCard
                } else {
                    chartFallbackCard
                }

                // Statistics Grid
                statisticsGrid

                // Zone Information
                zoneInfoCard

                // Refresh Button
                refreshButton
            }
            .padding(AppTheme.Layout.paddingLarge)
        }
        .background(AppTheme.Colors.groupedBackground)
        .navigationTitle("Heart Rate")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshData()
        }
        .alert("Heart Rate Alert", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Hero Heart Rate Card

    private var heroHeartRateCard: some View {
        ModernCard {
            VStack(spacing: AppTheme.Layout.spacingLarge) {
                HStack {
                    Text("Current Heart Rate")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Spacer()

                    if let hr = currentHeartRate {
                        HeartRateZoneBadge(heartRate: Int(hr.bpm))
                    }
                }

                if let hr = currentHeartRate {
                    AnimatedHeartRate(
                        heartRate: Int(hr.bpm),
                        isAnimating: healthService.isConnected
                    )

                    // Alert Banner
                    if hr.isAlert {
                        HStack(spacing: AppTheme.Layout.spacingMedium) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppTheme.Colors.warning)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Heart Rate Variation Detected")
                                    .font(AppTheme.Typography.captionBold)
                                    .foregroundColor(AppTheme.Colors.danger)

                                Text("Monitor closely and consult a healthcare professional if persistent")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(AppTheme.Layout.paddingMedium)
                        .background(AppTheme.Colors.danger.opacity(0.1))
                        .cornerRadius(AppTheme.Layout.cornerRadiusMedium)
                    }

                    // Last Updated
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .font(.caption)

                        Text("Updated: \(hr.timestamp, style: .relative)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)

                        Spacer()

                        LiveDataIndicator(isLive: healthService.isConnected)
                    }
                } else {
                    LoadingView(message: "Waiting for heart rate data...")
                        .frame(height: 200)
                }
            }
        }
    }

    // MARK: - Chart Card

    @available(iOS 16.0, *)
    private var chartCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(AppTheme.Colors.primary)
                    Text("Heart Rate History")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Spacer()
                    Text("\(heartRateHistory.count) readings")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                if heartRateHistory.isEmpty {
                    EmptyStateView(
                        icon: "waveform.path.ecg",
                        title: "No History Yet",
                        message: "Heart rate data will appear here as it's collected",
                        actionTitle: nil,
                        action: nil
                    )
                    .frame(height: 200)
                } else {
                    Chart(heartRateHistory) { data in
                        LineMark(
                            x: .value("Time", data.timestamp),
                            y: .value("BPM", data.bpm)
                        )
                        .foregroundStyle(data.isAlert ? AppTheme.Colors.danger : AppTheme.Colors.heartRate)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3))

                        AreaMark(
                            x: .value("Time", data.timestamp),
                            y: .value("BPM", data.bpm)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    (data.isAlert ? AppTheme.Colors.danger : AppTheme.Colors.heartRate).opacity(0.3),
                                    (data.isAlert ? AppTheme.Colors.danger : AppTheme.Colors.heartRate).opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        if data.isAlert {
                            PointMark(
                                x: .value("Time", data.timestamp),
                                y: .value("BPM", data.bpm)
                            )
                            .foregroundStyle(AppTheme.Colors.danger)
                            .symbolSize(80)
                        }
                    }
                    .frame(height: 220)
                    .chartYScale(domain: 40...140)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                }
            }
        }
    }

    private var chartFallbackCard: some View {
        ModernCard {
            VStack(spacing: AppTheme.Layout.spacingMedium) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.Colors.textTertiary)

                Text("Chart Unavailable")
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("Heart rate charts require iOS 16 or later")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Statistics Grid

    private var statisticsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: AppTheme.Layout.spacingMedium),
                GridItem(.flexible(), spacing: AppTheme.Layout.spacingMedium),
                GridItem(.flexible(), spacing: AppTheme.Layout.spacingMedium)
            ],
            spacing: AppTheme.Layout.spacingMedium
        ) {
            StatCard(
                icon: "chart.bar.fill",
                title: "Average",
                value: String(format: "%.0f", calculateAverage()),
                unit: "BPM",
                color: AppTheme.Colors.info
            )

            StatCard(
                icon: "arrow.down.circle.fill",
                title: "Min",
                value: String(format: "%.0f", heartRateHistory.map { $0.bpm }.min() ?? 0),
                unit: "BPM",
                color: AppTheme.Colors.success
            )

            StatCard(
                icon: "arrow.up.circle.fill",
                title: "Max",
                value: String(format: "%.0f", heartRateHistory.map { $0.bpm }.max() ?? 0),
                unit: "BPM",
                color: AppTheme.Colors.warning
            )
        }
    }

    // MARK: - Zone Info Card

    private var zoneInfoCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                HStack {
                    Image(systemName: "heart.text.square")
                        .foregroundColor(AppTheme.Colors.primary)
                    Text("Heart Rate Zones")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Spacer()
                }

                Divider()

                VStack(spacing: AppTheme.Layout.spacingSmall) {
                    ZoneRow(range: "< 40 BPM", label: "Very Low", color: AppTheme.Colors.danger)
                    ZoneRow(range: "40-60 BPM", label: "Low", color: AppTheme.Colors.info)
                    ZoneRow(range: "60-100 BPM", label: "Normal", color: AppTheme.Colors.success)
                    ZoneRow(range: "100-120 BPM", label: "Elevated", color: AppTheme.Colors.warning)
                    ZoneRow(range: "> 120 BPM", label: "High", color: AppTheme.Colors.danger)
                }
            }
        }
    }

    // MARK: - Refresh Button

    private var refreshButton: some View {
        ModernButton(
            title: "Refresh Data",
            icon: "arrow.clockwise",
            style: .primary,
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
            currentHeartRate = healthService.getCurrentHeartRate()
            heartRateHistory = healthService.getHeartRateHistory(limit: 100)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
    }

    private func calculateAverage() -> Double {
        guard !heartRateHistory.isEmpty else { return 0 }
        return heartRateHistory.map { $0.bpm }.reduce(0, +) / Double(heartRateHistory.count)
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: AppTheme.Layout.spacingSmall) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)

            Text(value)
                .font(AppTheme.Typography.sectionTitle)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(unit)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Layout.paddingMedium)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.Layout.cornerRadiusMedium)
        .shadow(
            color: AppTheme.Shadows.small.color,
            radius: AppTheme.Shadows.small.radius,
            x: AppTheme.Shadows.small.x,
            y: AppTheme.Shadows.small.y
        )
    }
}

// MARK: - Zone Row Component

struct ZoneRow: View {
    let range: String
    let label: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(range)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(width: 100, alignment: .leading)

            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)

            Spacer()
        }
        .padding(AppTheme.Layout.paddingSmall)
        .background(color.opacity(0.1))
        .cornerRadius(AppTheme.Layout.cornerRadiusSmall)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        HeartRateView()
            .environmentObject(HealthMonitoringService.shared)
    }
}
