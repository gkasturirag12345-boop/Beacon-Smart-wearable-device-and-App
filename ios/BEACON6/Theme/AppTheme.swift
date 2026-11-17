//
//  AppTheme.swift
//  BEACON
//
//  Centralized theming system for modern, adaptive UI
//  Supports Light/Dark mode and responsive layouts
//

import SwiftUI

struct AppTheme {

    // MARK: - Color Palette

    struct Colors {
        // Primary brand colors
        static let primary = Color("AccentColor")
        static let secondary = Color.blue.opacity(0.8)

        // Background colors
        static let background = Color(UIColor.systemBackground)
        static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
        static let groupedBackground = Color(UIColor.systemGroupedBackground)

        // Status colors
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red.opacity(0.9)
        static let info = Color.blue

        // Feature-specific colors
        static let heartRate = Color.pink
        static let bluetooth = Color.blue
        static let fallAlert = Color.red.opacity(0.85)

        // Text colors
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color(UIColor.tertiaryLabel)

        // Border and divider
        static let border = Color(UIColor.separator)
        static let divider = Color(UIColor.separator).opacity(0.5)
    }

    // MARK: - Typography

    struct Typography {
        // Hero/Display text
        static let hero = Font.system(size: 72, weight: .bold, design: .rounded)
        static let heroTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)

        // Section titles
        static let sectionTitle = Font.system(.title2, design: .rounded).weight(.semibold)
        static let sectionSubtitle = Font.system(.title3, design: .rounded).weight(.medium)

        // Card content
        static let cardTitle = Font.system(.headline, design: .rounded).weight(.semibold)
        static let cardSubtitle = Font.system(.subheadline, design: .default).weight(.medium)

        // Body text
        static let body = Font.body
        static let bodyBold = Font.body.weight(.semibold)

        // Small text
        static let caption = Font.caption
        static let captionBold = Font.caption.weight(.semibold)
        static let footnote = Font.footnote

        // Status/Badge text
        static let badge = Font.system(size: 11, weight: .semibold, design: .rounded)
    }

    // MARK: - Layout & Spacing

    struct Layout {
        // Corner radius
        static let cornerRadiusSmall: CGFloat = 8
        static let cornerRadiusMedium: CGFloat = 12
        static let cornerRadiusLarge: CGFloat = 16
        static let cornerRadiusXLarge: CGFloat = 24

        // Padding
        static let paddingXSmall: CGFloat = 4
        static let paddingSmall: CGFloat = 8
        static let paddingMedium: CGFloat = 12
        static let paddingLarge: CGFloat = 16
        static let paddingXLarge: CGFloat = 24

        // Spacing between elements
        static let spacingXSmall: CGFloat = 4
        static let spacingSmall: CGFloat = 8
        static let spacingMedium: CGFloat = 12
        static let spacingLarge: CGFloat = 16
        static let spacingXLarge: CGFloat = 24
        static let spacingXXLarge: CGFloat = 32

        // Card dimensions
        static let cardMinHeight: CGFloat = 80
        static let cardMaxWidth: CGFloat = 600

        // Icon sizes
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 24
        static let iconLarge: CGFloat = 32
        static let iconXLarge: CGFloat = 48
    }

    // MARK: - Shadows

    struct Shadows {
        static let small = Shadow(
            color: Color.black.opacity(0.08),
            radius: 4,
            x: 0,
            y: 2
        )

        static let medium = Shadow(
            color: Color.black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )

        static let large = Shadow(
            color: Color.black.opacity(0.12),
            radius: 16,
            x: 0,
            y: 8
        )

        struct Shadow {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
    }

    // MARK: - Blur Effects

    enum BlurStyle {
        case thin
        case regular
        case thick

        var material: Material {
            switch self {
            case .thin: return .thinMaterial
            case .regular: return .regularMaterial
            case .thick: return .thickMaterial
            }
        }
    }
}

// MARK: - View Extensions for Easy Theming

extension View {
    /// Apply standard card styling
    func cardStyle() -> some View {
        self
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(AppTheme.Layout.cornerRadiusLarge)
            .shadow(
                color: AppTheme.Shadows.medium.color,
                radius: AppTheme.Shadows.medium.radius,
                x: AppTheme.Shadows.medium.x,
                y: AppTheme.Shadows.medium.y
            )
    }

    /// Apply compact card styling (less shadow)
    func compactCardStyle() -> some View {
        self
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(AppTheme.Layout.cornerRadiusMedium)
            .shadow(
                color: AppTheme.Shadows.small.color,
                radius: AppTheme.Shadows.small.radius,
                x: AppTheme.Shadows.small.x,
                y: AppTheme.Shadows.small.y
            )
    }

    /// Apply section padding
    func sectionPadding() -> some View {
        self.padding(.horizontal, AppTheme.Layout.paddingLarge)
            .padding(.vertical, AppTheme.Layout.paddingMedium)
    }
}

// MARK: - Color Status Helpers

extension Color {
    /// Get status color based on boolean state
    static func statusColor(isActive: Bool) -> Color {
        isActive ? AppTheme.Colors.success : AppTheme.Colors.textSecondary
    }
}
