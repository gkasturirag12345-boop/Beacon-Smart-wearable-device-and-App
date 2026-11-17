//
//  ModernButton.swift
//  BEACON
//
//  Modern button components with haptic feedback
//

import SwiftUI

/// Modern button with various styles
struct ModernButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticFeedback.medium()
            action()
        }) {
            HStack(spacing: AppTheme.Layout.spacingSmall) {
                if isLoading {
                    ProgressView()
                        .tint(style.foregroundColor)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: AppTheme.Layout.iconMedium))
                    }

                    Text(title)
                        .font(AppTheme.Typography.bodyBold)
                }
            }
            .foregroundColor(style.foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Layout.paddingMedium)
            .background(style.backgroundColor)
            .cornerRadius(AppTheme.Layout.cornerRadiusMedium)
            .opacity(isDisabled || isLoading ? 0.6 : 1.0)
        }
        .disabled(isDisabled || isLoading)
    }

    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        case ghost
        case success

        var backgroundColor: Color {
            switch self {
            case .primary:
                return AppTheme.Colors.primary
            case .secondary:
                return AppTheme.Colors.cardBackground
            case .destructive:
                return AppTheme.Colors.danger
            case .ghost:
                return Color.clear
            case .success:
                return AppTheme.Colors.success
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary:
                return .black
            case .destructive, .success:
                return .white
            case .secondary, .ghost:
                return AppTheme.Colors.textPrimary
            }
        }
    }
}

/// Icon-only button
struct IconButton: View {
    let icon: String
    let color: Color
    let size: IconSize
    let action: () -> Void

    init(
        icon: String,
        color: Color = AppTheme.Colors.primary,
        size: IconSize = .medium,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.color = color
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticFeedback.light()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize))
                .foregroundColor(color)
                .frame(width: size.frameSize, height: size.frameSize)
                .background(color.opacity(0.15))
                .cornerRadius(size.cornerRadius)
        }
    }

    enum IconSize {
        case small, medium, large

        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 24
            case .large: return 32
            }
        }

        var frameSize: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 44
            case .large: return 56
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return AppTheme.Layout.cornerRadiusSmall
            case .medium: return AppTheme.Layout.cornerRadiusMedium
            case .large: return AppTheme.Layout.cornerRadiusLarge
            }
        }
    }
}

/// Alert button with glow effect
struct AlertButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    @State private var isPressing = false

    var body: some View {
        Button(action: {
            HapticFeedback.heavy()
            action()
        }) {
            VStack(spacing: AppTheme.Layout.spacingSmall) {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(.white)

                Text(title)
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Layout.paddingXLarge)
            .background(
                LinearGradient(
                    colors: isActive ? [Color.red, Color.red.opacity(0.8)] : [Color.gray, Color.gray.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(AppTheme.Layout.cornerRadiusLarge)
            .shadow(
                color: isActive ? Color.red.opacity(0.6) : Color.clear,
                radius: isPressing ? 30 : 20
            )
            .scaleEffect(isPressing ? 0.95 : 1.0)
        }
        .buttonStyle(PressButtonStyle(isPressing: $isPressing))
    }
}

/// Custom button style for press animations
struct PressButtonStyle: ButtonStyle {
    @Binding var isPressing: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                withAnimation(AnimationConfig.quick) {
                    isPressing = newValue
                }
            }
    }
}

/// Toggle-style button (for features that can be enabled/disabled)
struct ToggleButton: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: {
            HapticFeedback.selection()
            withAnimation(AnimationConfig.smooth) {
                isOn.toggle()
            }
        }) {
            HStack(spacing: AppTheme.Layout.spacingMedium) {
                Image(systemName: icon)
                    .font(.system(size: AppTheme.Layout.iconLarge))
                    .foregroundColor(isOn ? .white : AppTheme.Colors.textPrimary)

                Text(title)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundColor(isOn ? .white : AppTheme.Colors.textPrimary)

                Spacer()

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: AppTheme.Layout.iconMedium))
                    .foregroundColor(isOn ? .white : AppTheme.Colors.textSecondary)
            }
            .padding(AppTheme.Layout.paddingLarge)
            .background(
                isOn ? AppTheme.Colors.success : AppTheme.Colors.cardBackground
            )
            .cornerRadius(AppTheme.Layout.cornerRadiusLarge)
        }
    }
}

/// Floating action button
struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticFeedback.heavy()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(color)
                .clipShape(Circle())
                .shadow(
                    color: color.opacity(0.4),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        }
    }
}

/// Pill-style selector button
struct PillButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticFeedback.selection()
            action()
        }) {
            Text(title)
                .font(AppTheme.Typography.bodyBold)
                .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Layout.paddingLarge)
                .padding(.vertical, AppTheme.Layout.paddingSmall)
                .background(
                    isSelected ? AppTheme.Colors.primary : AppTheme.Colors.cardBackground
                )
                .cornerRadius(AppTheme.Layout.cornerRadiusXLarge)
        }
    }
}

// MARK: - Preview

#Preview("Modern Buttons") {
    ScrollView {
        VStack(spacing: 20) {
            Group {
                Text("Standard Buttons")
                    .font(AppTheme.Typography.sectionTitle)

                ModernButton(title: "Primary Button", style: .primary) {}
                ModernButton(title: "Secondary Button", style: .secondary) {}
                ModernButton(title: "Destructive Button", style: .destructive) {}
                ModernButton(title: "Success Button", style: .success) {}
                ModernButton(title: "Ghost Button", style: .ghost) {}
            }

            Divider()

            Group {
                Text("Buttons with Icons")
                    .font(AppTheme.Typography.sectionTitle)

                ModernButton(title: "Connect", icon: "antenna.radiowaves.left.and.right", style: .primary) {}
                ModernButton(title: "Disconnect", icon: "xmark", style: .destructive) {}
                ModernButton(title: "Loading...", icon: "arrow.clockwise", style: .primary, isLoading: true) {}
                ModernButton(title: "Disabled", icon: "lock.fill", style: .primary, isDisabled: true) {}
            }

            Divider()

            Group {
                Text("Icon Buttons")
                    .font(AppTheme.Typography.sectionTitle)

                HStack(spacing: 16) {
                    IconButton(icon: "heart.fill", color: .pink, size: .small) {}
                    IconButton(icon: "heart.fill", color: .pink, size: .medium) {}
                    IconButton(icon: "heart.fill", color: .pink, size: .large) {}
                }
            }

            Divider()

            Group {
                Text("Alert Button")
                    .font(AppTheme.Typography.sectionTitle)

                AlertButton(title: "Emergency Alert", icon: "exclamationmark.triangle.fill", isActive: true) {}
                AlertButton(title: "Inactive Alert", icon: "exclamationmark.triangle", isActive: false) {}
            }

            Divider()

            Group {
                Text("Toggle Buttons")
                    .font(AppTheme.Typography.sectionTitle)

                ToggleButton(title: "Fall Detection", icon: "figure.fall", isOn: .constant(true))
                ToggleButton(title: "Heart Monitor", icon: "heart.fill", isOn: .constant(false))
            }

            Divider()

            Group {
                Text("Floating Action Button")
                    .font(AppTheme.Typography.sectionTitle)

                HStack(spacing: 20) {
                    FloatingActionButton(icon: "plus", color: .blue) {}
                    FloatingActionButton(icon: "phone.fill", color: .green) {}
                    FloatingActionButton(icon: "bell.fill", color: .red) {}
                }
            }

            Divider()

            Group {
                Text("Pill Buttons")
                    .font(AppTheme.Typography.sectionTitle)

                HStack(spacing: 12) {
                    PillButton(title: "All", isSelected: true) {}
                    PillButton(title: "Active", isSelected: false) {}
                    PillButton(title: "History", isSelected: false) {}
                }
            }
        }
        .padding()
    }
    .background(AppTheme.Colors.groupedBackground)
}
