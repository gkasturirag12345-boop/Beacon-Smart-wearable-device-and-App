//
//  ModernCard.swift
//  BEACON
//
//  Reusable modern card component with adaptive styling
//

import SwiftUI

/// Modern card container with rounded corners, shadow, and adaptive styling
struct ModernCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat
    let shadowStyle: ShadowStyle

    init(
        padding: CGFloat = AppTheme.Layout.paddingLarge,
        cornerRadius: CGFloat = AppTheme.Layout.cornerRadiusLarge,
        shadowStyle: ShadowStyle = .medium,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadowStyle = shadowStyle
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(cornerRadius)
            .shadow(
                color: shadowStyle.shadow.color,
                radius: shadowStyle.shadow.radius,
                x: shadowStyle.shadow.x,
                y: shadowStyle.shadow.y
            )
    }

    enum ShadowStyle {
        case none, small, medium, large

        var shadow: AppTheme.Shadows.Shadow {
            switch self {
            case .none:
                return AppTheme.Shadows.Shadow(color: .clear, radius: 0, x: 0, y: 0)
            case .small:
                return AppTheme.Shadows.small
            case .medium:
                return AppTheme.Shadows.medium
            case .large:
                return AppTheme.Shadows.large
            }
        }
    }
}

/// Compact card for dense information
struct CompactCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ModernCard(
            padding: AppTheme.Layout.paddingMedium,
            cornerRadius: AppTheme.Layout.cornerRadiusMedium,
            shadowStyle: .small
        ) {
            content
        }
    }
}

/// Info card with icon, title, and value
struct InfoCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String?

    init(
        icon: String,
        iconColor: Color = AppTheme.Colors.primary,
        title: String,
        value: String,
        subtitle: String? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.value = value
        self.subtitle = subtitle
    }

    var body: some View {
        ModernCard {
            HStack(spacing: AppTheme.Layout.spacingMedium) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: AppTheme.Layout.iconLarge))
                    .foregroundColor(iconColor)
                    .frame(width: 50, height: 50)
                    .background(iconColor.opacity(0.15))
                    .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

                // Content
                VStack(alignment: .leading, spacing: AppTheme.Layout.spacingXSmall) {
                    Text(title)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    Text(value)
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }

                Spacer()
            }
        }
    }
}

/// Status card with large metric display
struct MetricCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let unit: String
    let status: String?
    let statusColor: Color?

    init(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        unit: String = "",
        status: String? = nil,
        statusColor: Color? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.value = value
        self.unit = unit
        self.status = status
        self.statusColor = statusColor
    }

    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                // Header with icon and title
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: AppTheme.Layout.iconMedium))
                        .foregroundColor(iconColor)

                    Text(title)
                        .font(AppTheme.Typography.cardSubtitle)
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    Spacer()

                    // Status badge
                    if let status = status, let statusColor = statusColor {
                        StatusBadge(text: status, color: statusColor)
                    }
                }

                // Large value display
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Layout.spacingSmall) {
                    Text(value)
                        .font(AppTheme.Typography.hero)
                        .foregroundColor(iconColor)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(AppTheme.Typography.sectionTitle)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

/// Action card with button
struct ActionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let buttonText: String
    let isLoading: Bool
    let action: () -> Void

    init(
        icon: String,
        iconColor: Color = AppTheme.Colors.primary,
        title: String,
        subtitle: String,
        buttonText: String,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.buttonText = buttonText
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                HStack(spacing: AppTheme.Layout.spacingMedium) {
                    Image(systemName: icon)
                        .font(.system(size: AppTheme.Layout.iconLarge))
                        .foregroundColor(iconColor)

                    VStack(alignment: .leading, spacing: AppTheme.Layout.spacingXSmall) {
                        Text(title)
                            .font(AppTheme.Typography.cardTitle)
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        Text(subtitle)
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                ModernButton(
                    title: buttonText,
                    style: .primary,
                    isLoading: isLoading,
                    action: action
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("ModernCard Styles") {
    ScrollView {
        VStack(spacing: 16) {
            ModernCard {
                Text("Basic Card")
            }

            CompactCard {
                Text("Compact Card")
            }

            InfoCard(
                icon: "heart.fill",
                iconColor: .pink,
                title: "Heart Rate",
                value: "72 BPM",
                subtitle: "Normal"
            )

            MetricCard(
                icon: "heart.fill",
                iconColor: .pink,
                title: "Heart Rate",
                value: "72",
                unit: "BPM",
                status: "Normal",
                statusColor: .green
            )

            ActionCard(
                icon: "antenna.radiowaves.left.and.right.circle.fill",
                iconColor: .blue,
                title: "Connect Wearable",
                subtitle: "Pair the BEACON device over Bluetooth",
                buttonText: "Configure"
            ) {
                print("Action tapped")
            }
        }
        .padding()
    }
    .background(AppTheme.Colors.groupedBackground)
}
