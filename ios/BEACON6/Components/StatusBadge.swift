//
//  StatusBadge.swift
//  BEACON
//
//  Status badge component for displaying connection states, alerts, etc.
//

import SwiftUI

/// Colored badge for status indicators
struct StatusBadge: View {
    let text: String
    let color: Color
    let style: BadgeStyle

    init(
        text: String,
        color: Color,
        style: BadgeStyle = .filled
    ) {
        self.text = text
        self.color = color
        self.style = style
    }

    var body: some View {
        Text(text)
            .font(AppTheme.Typography.badge)
            .foregroundColor(style == .filled ? .white : color)
            .padding(.horizontal, AppTheme.Layout.paddingSmall)
            .padding(.vertical, AppTheme.Layout.paddingXSmall)
            .background(
                Capsule()
                    .fill(style == .filled ? color : color.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .strokeBorder(style == .outlined ? color : Color.clear, lineWidth: 1.5)
            )
    }

    enum BadgeStyle {
        case filled
        case outlined
    }
}

/// Connection status badge with icon
struct ConnectionStatusBadge: View {
    let mode: ConnectionMode
    let isConnected: Bool

    var body: some View {
        HStack(spacing: AppTheme.Layout.spacingXSmall) {
            Image(systemName: mode.iconName)
                .font(.system(size: 10, weight: .semibold))

            Text(mode.displayName)
                .font(AppTheme.Typography.badge)
        }
        .foregroundColor(.white)
        .padding(.horizontal, AppTheme.Layout.paddingSmall)
        .padding(.vertical, AppTheme.Layout.paddingXSmall)
        .background(
            Capsule()
                .fill(isConnected ? statusColor : Color.gray)
        )
    }

    private var statusColor: Color {
        switch mode {
        case .wifi:
            return AppTheme.Colors.wifi
        case .ble:
            return AppTheme.Colors.bluetooth
        case .offline:
            return Color.gray
        }
    }
}

/// Signal strength indicator
struct SignalStrengthBadge: View {
    let rssi: Int // Signal strength in dBm

    var body: some View {
        HStack(spacing: AppTheme.Layout.spacingXSmall) {
            Image(systemName: signalIcon)
                .font(.system(size: 10, weight: .semibold))

            Text(signalText)
                .font(AppTheme.Typography.badge)
        }
        .foregroundColor(.white)
        .padding(.horizontal, AppTheme.Layout.paddingSmall)
        .padding(.vertical, AppTheme.Layout.paddingXSmall)
        .background(
            Capsule()
                .fill(signalColor)
        )
    }

    private var signalIcon: String {
        if rssi >= -50 {
            return "wifi"
        } else if rssi >= -70 {
            return "wifi"
        } else {
            return "wifi.exclamationmark"
        }
    }

    private var signalText: String {
        if rssi >= -50 {
            return "Excellent"
        } else if rssi >= -70 {
            return "Good"
        } else if rssi >= -80 {
            return "Fair"
        } else {
            return "Weak"
        }
    }

    private var signalColor: Color {
        if rssi >= -50 {
            return AppTheme.Colors.success
        } else if rssi >= -70 {
            return AppTheme.Colors.info
        } else if rssi >= -80 {
            return AppTheme.Colors.warning
        } else {
            return AppTheme.Colors.danger
        }
    }
}

/// Heart rate zone badge
struct HeartRateZoneBadge: View {
    let heartRate: Int
    let restingHeartRate: Int = 60 // Default, could be customizable

    var body: some View {
        StatusBadge(
            text: zoneText,
            color: zoneColor,
            style: .filled
        )
    }

    private var zoneText: String {
        let percentage = Double(heartRate) / Double(restingHeartRate)

        if heartRate < 40 {
            return "Very Low"
        } else if heartRate < 60 {
            return "Low"
        } else if percentage < 1.3 {
            return "Normal"
        } else if percentage < 1.5 {
            return "Elevated"
        } else {
            return "High"
        }
    }

    private var zoneColor: Color {
        let percentage = Double(heartRate) / Double(restingHeartRate)

        if heartRate < 40 {
            return AppTheme.Colors.danger
        } else if heartRate < 60 {
            return AppTheme.Colors.info
        } else if percentage < 1.3 {
            return AppTheme.Colors.success
        } else if percentage < 1.5 {
            return AppTheme.Colors.warning
        } else {
            return AppTheme.Colors.danger
        }
    }
}

/// Alert severity badge
struct AlertSeverityBadge: View {
    let severity: AlertSeverity

    var body: some View {
        HStack(spacing: AppTheme.Layout.spacingXSmall) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))

            Text(text)
                .font(AppTheme.Typography.badge)
        }
        .foregroundColor(.white)
        .padding(.horizontal, AppTheme.Layout.paddingSmall)
        .padding(.vertical, AppTheme.Layout.paddingXSmall)
        .background(
            Capsule()
                .fill(color)
        )
    }

    private var text: String {
        switch severity {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    private var icon: String {
        switch severity {
        case .low: return "info.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.octagon.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private var color: Color {
        switch severity {
        case .low: return AppTheme.Colors.info
        case .medium: return AppTheme.Colors.warning
        case .high: return AppTheme.Colors.danger
        case .critical: return AppTheme.Colors.danger
        }
    }
}

/// Animated pulse dot (for live indicators)
struct PulseDot: View {
    let color: Color
    let isAnimating: Bool

    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .animation(
                isAnimating ? AnimationConfig.pulse : .default,
                value: scale
            )
            .onAppear {
                if isAnimating {
                    scale = 1.3
                }
            }
    }
}

// MARK: - Preview

#Preview("Status Badges") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                Text("Basic Badges")
                    .font(AppTheme.Typography.sectionTitle)

                HStack(spacing: 12) {
                    StatusBadge(text: "Active", color: .green, style: .filled)
                    StatusBadge(text: "Pending", color: .orange, style: .filled)
                    StatusBadge(text: "Error", color: .red, style: .filled)
                }

                HStack(spacing: 12) {
                    StatusBadge(text: "Active", color: .green, style: .outlined)
                    StatusBadge(text: "Pending", color: .orange, style: .outlined)
                    StatusBadge(text: "Error", color: .red, style: .outlined)
                }
            }

            Divider()

            Group {
                Text("Connection Status")
                    .font(AppTheme.Typography.sectionTitle)

                HStack(spacing: 12) {
                    ConnectionStatusBadge(mode: .wifi, isConnected: true)
                    ConnectionStatusBadge(mode: .ble, isConnected: true)
                    ConnectionStatusBadge(mode: .offline, isConnected: false)
                }
            }

            Divider()

            Group {
                Text("Signal Strength")
                    .font(AppTheme.Typography.sectionTitle)

                VStack(alignment: .leading, spacing: 8) {
                    SignalStrengthBadge(rssi: -40)
                    SignalStrengthBadge(rssi: -60)
                    SignalStrengthBadge(rssi: -75)
                    SignalStrengthBadge(rssi: -85)
                }
            }

            Divider()

            Group {
                Text("Heart Rate Zones")
                    .font(AppTheme.Typography.sectionTitle)

                VStack(alignment: .leading, spacing: 8) {
                    HeartRateZoneBadge(heartRate: 35)
                    HeartRateZoneBadge(heartRate: 55)
                    HeartRateZoneBadge(heartRate: 72)
                    HeartRateZoneBadge(heartRate: 95)
                    HeartRateZoneBadge(heartRate: 120)
                }
            }

            Divider()

            Group {
                Text("Alert Severity")
                    .font(AppTheme.Typography.sectionTitle)

                VStack(alignment: .leading, spacing: 8) {
                    AlertSeverityBadge(severity: .low)
                    AlertSeverityBadge(severity: .medium)
                    AlertSeverityBadge(severity: .high)
                }
            }

            Divider()

            Group {
                Text("Pulse Dots")
                    .font(AppTheme.Typography.sectionTitle)

                HStack(spacing: 12) {
                    PulseDot(color: .green, isAnimating: true)
                    PulseDot(color: .orange, isAnimating: true)
                    PulseDot(color: .red, isAnimating: true)
                    PulseDot(color: .gray, isAnimating: false)
                }
            }
        }
        .padding()
    }
    .background(AppTheme.Colors.groupedBackground)
}
