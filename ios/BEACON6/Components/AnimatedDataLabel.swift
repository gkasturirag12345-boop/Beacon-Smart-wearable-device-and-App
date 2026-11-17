//
//  AnimatedDataLabel.swift
//  BEACON
//
//  Animated numeric displays with smooth transitions
//

import SwiftUI

/// Animated heart rate display with pulse effect
struct AnimatedHeartRate: View {
    let heartRate: Int
    let isAnimating: Bool

    @State private var pulse = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Layout.spacingSmall) {
            // Heart icon with pulse
            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.Colors.heartRate)
                .scaleEffect(pulse && isAnimating ? 1.2 : 1.0)
                .animation(
                    isAnimating ? AnimationConfig.heartbeat : .default,
                    value: pulse
                )

            // Animated number
            AnimatedNumber(
                value: heartRate,
                font: AppTheme.Typography.hero,
                color: AppTheme.Colors.heartRate
            )

            Text("BPM")
                .font(AppTheme.Typography.sectionTitle)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .onAppear {
            if isAnimating {
                withAnimation {
                    pulse = true
                }
            }
        }
        .onChange(of: isAnimating) { oldValue, newValue in
            pulse = newValue
        }
    }
}

/// Large metric display with optional subtitle
struct LargeMetricDisplay: View {
    let value: String
    let unit: String
    let subtitle: String?
    let color: Color

    init(
        value: String,
        unit: String = "",
        subtitle: String? = nil,
        color: Color = AppTheme.Colors.primary
    ) {
        self.value = value
        self.unit = unit
        self.subtitle = subtitle
        self.color = color
    }

    var body: some View {
        VStack(spacing: AppTheme.Layout.spacingXSmall) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Layout.spacingSmall) {
                Text(value)
                    .font(AppTheme.Typography.hero)
                    .foregroundColor(color)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if !unit.isEmpty {
                    Text(unit)
                        .font(AppTheme.Typography.sectionTitle)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
    }
}

/// Percentage ring with animated progress
struct PercentageRing: View {
    let percentage: Double // 0-100
    let color: Color
    let label: String?

    private var progress: Double {
        percentage / 100.0
    }

    var body: some View {
        ZStack {
            // Progress ring
            ProgressRing(
                progress: progress,
                color: color,
                lineWidth: 8
            )
            .frame(width: 80, height: 80)

            // Center text
            VStack(spacing: 2) {
                Text("\(Int(percentage))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(color)

                Text("%")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .frame(width: 100, height: 100)
        .overlay(
            label.map { labelText in
                Text(labelText)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .offset(y: 60)
            }
        )
    }
}

/// Status indicator with icon and text
struct StatusIndicator: View {
    let icon: String
    let text: String
    let color: Color
    let isActive: Bool

    var body: some View {
        HStack(spacing: AppTheme.Layout.spacingSmall) {
            Image(systemName: icon)
                .font(.system(size: AppTheme.Layout.iconMedium))
                .foregroundColor(color)
                .opacity(isActive ? 1.0 : 0.5)

            Text(text)
                .font(AppTheme.Typography.body)
                .foregroundColor(isActive ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, AppTheme.Layout.paddingMedium)
        .padding(.vertical, AppTheme.Layout.paddingSmall)
        .background(
            Capsule()
                .fill(isActive ? color.opacity(0.15) : Color.clear)
        )
    }
}

/// Countdown timer display
struct CountdownDisplay: View {
    let seconds: Int
    let color: Color

    private var formattedTime: String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Layout.spacingXSmall) {
            Image(systemName: "clock.fill")
                .font(.system(size: AppTheme.Layout.iconMedium))
                .foregroundColor(color)

            Text(formattedTime)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText(value: Double(seconds)))
        }
    }
}

/// Live data stream indicator
struct LiveDataIndicator: View {
    let isLive: Bool

    var body: some View {
        HStack(spacing: AppTheme.Layout.spacingXSmall) {
            PulseDot(color: isLive ? .green : .gray, isAnimating: isLive)

            Text(isLive ? "LIVE" : "OFFLINE")
                .font(AppTheme.Typography.badge)
                .foregroundColor(isLive ? .green : .gray)
        }
        .padding(.horizontal, AppTheme.Layout.paddingSmall)
        .padding(.vertical, AppTheme.Layout.paddingXSmall)
        .background(
            Capsule()
                .fill((isLive ? Color.green : Color.gray).opacity(0.15))
        )
    }
}

/// Comparison bar (for showing progress/comparison)
struct ComparisonBar: View {
    let label: String
    let currentValue: Double
    let maxValue: Double
    let color: Color

    private var percentage: Double {
        min(currentValue / maxValue, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Layout.spacingXSmall) {
            HStack {
                Text(label)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                Spacer()

                Text("\(Int(currentValue)) / \(Int(maxValue))")
                    .font(AppTheme.Typography.captionBold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(AppTheme.Colors.border.opacity(0.3))

                    // Progress
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage)
                        .animation(AnimationConfig.smooth, value: percentage)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Preview

#Preview("Animated Data Labels") {
    ScrollView {
        VStack(spacing: 24) {
            ModernCard {
                AnimatedHeartRate(heartRate: 72, isAnimating: true)
            }

            ModernCard {
                LargeMetricDisplay(
                    value: "98",
                    unit: "%",
                    subtitle: "Blood Oxygen",
                    color: .blue
                )
            }

            HStack(spacing: 16) {
                PercentageRing(percentage: 75, color: .green, label: "Battery")
                PercentageRing(percentage: 45, color: .orange, label: "Activity")
            }

            ModernCard {
                VStack(alignment: .leading, spacing: 12) {
                    StatusIndicator(icon: "heart.fill", text: "Heart Rate Monitor", color: .pink, isActive: true)
                    StatusIndicator(icon: "figure.fall", text: "Fall Detection", color: .orange, isActive: true)
                    StatusIndicator(icon: "bell.fill", text: "Alert System", color: .red, isActive: false)
                }
            }

            ModernCard {
                CountdownDisplay(seconds: 125, color: .red)
            }

            HStack(spacing: 16) {
                LiveDataIndicator(isLive: true)
                LiveDataIndicator(isLive: false)
            }

            ModernCard {
                VStack(spacing: 12) {
                    ComparisonBar(label: "Steps Today", currentValue: 7500, maxValue: 10000, color: .green)
                    ComparisonBar(label: "Active Minutes", currentValue: 35, maxValue: 60, color: .orange)
                    ComparisonBar(label: "Calories", currentValue: 420, maxValue: 500, color: .red)
                }
            }
        }
        .padding()
    }
    .background(AppTheme.Colors.groupedBackground)
}
