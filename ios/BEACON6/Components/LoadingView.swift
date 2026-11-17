//
//  LoadingView.swift
//  BEACON
//
//  Loading states and skeleton screens
//

import SwiftUI

/// Modern loading spinner
struct LoadingView: View {
    let message: String?

    init(message: String? = nil) {
        self.message = message
    }

    var body: some View {
        VStack(spacing: AppTheme.Layout.spacingLarge) {
            ModernSpinner()

            if let message = message {
                Text(message)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppTheme.Layout.paddingXLarge)
    }
}

/// Full-screen loading overlay
struct LoadingOverlay: View {
    let message: String?
    let isShowing: Bool

    init(message: String? = nil, isShowing: Bool) {
        self.message = message
        self.isShowing = isShowing
    }

    var body: some View {
        ZStack {
            if isShowing {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: AppTheme.Layout.spacingLarge) {
                    ModernSpinner()

                    if let message = message {
                        Text(message)
                            .font(AppTheme.Typography.bodyBold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Layout.paddingXLarge)
                    }
                }
                .padding(AppTheme.Layout.paddingXLarge)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadiusLarge)
                        .fill(.ultraThinMaterial)
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(AnimationConfig.smooth, value: isShowing)
    }
}

/// Skeleton loading card (for list items)
struct SkeletonCard: View {
    @State private var isAnimating = false

    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                // Header skeleton
                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 16)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 12)
                    }

                    Spacer()
                }

                // Content skeleton
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 200, height: 12)
                }
            }
        }
        .shimmer(isActive: true)
    }
}

/// Loading state for data fetch
struct DataLoadingState<Content: View>: View {
    let isLoading: Bool
    let error: String?
    let retryAction: (() -> Void)?
    let content: () -> Content

    init(
        isLoading: Bool,
        error: String? = nil,
        retryAction: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isLoading = isLoading
        self.error = error
        self.retryAction = retryAction
        self.content = content
    }

    var body: some View {
        Group {
            if isLoading {
                LoadingView(message: "Loading data...")
            } else if let error = error {
                ErrorView(
                    message: error,
                    retryAction: retryAction
                )
            } else {
                content()
            }
        }
    }
}

/// Error state view
struct ErrorView: View {
    let icon: String
    let message: String
    let retryAction: (() -> Void)?

    init(
        icon: String = "exclamationmark.triangle.fill",
        message: String,
        retryAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: AppTheme.Layout.spacingLarge) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.warning)

            Text(message)
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Layout.paddingXLarge)

            if let retryAction = retryAction {
                ModernButton(
                    title: "Try Again",
                    icon: "arrow.clockwise",
                    style: .secondary,
                    action: retryAction
                )
                .frame(maxWidth: 200)
            }
        }
        .padding(AppTheme.Layout.paddingXLarge)
    }
}

/// Empty state view
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: AppTheme.Layout.spacingLarge) {
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(AppTheme.Colors.textTertiary)

            VStack(spacing: AppTheme.Layout.spacingSmall) {
                Text(title)
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text(message)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                ModernButton(
                    title: actionTitle,
                    style: .primary,
                    action: action
                )
                .frame(maxWidth: 250)
            }
        }
        .padding(AppTheme.Layout.paddingXLarge)
    }
}

/// Connecting state (for BLE/WiFi)
struct ConnectingView: View {
    let deviceName: String
    let connectionType: String

    @State private var dots = ""

    var body: some View {
        VStack(spacing: AppTheme.Layout.spacingXLarge) {
            ZStack {
                // Pulsing circles
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 2)
                        .frame(width: 100 + CGFloat(index * 40), height: 100 + CGFloat(index * 40))
                        .scaleEffect(1.0)
                        .opacity(0.0)
                        .animation(
                            Animation.easeOut(duration: 2.0)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.4),
                            value: dots
                        )
                }

                // Center icon
                Image(systemName: connectionType == "WiFi" ? "wifi" : "antenna.radiowaves.left.and.right")
                    .font(.system(size: 50))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .frame(height: 200)

            VStack(spacing: AppTheme.Layout.spacingSmall) {
                Text("Connecting to \(deviceName)")
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("via \(connectionType)\(dots)")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(AppTheme.Layout.paddingXLarge)
        .onAppear {
            startDotAnimation()
        }
    }

    private func startDotAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if dots.count >= 3 {
                dots = ""
            } else {
                dots += "."
            }
        }
    }
}

/// Success animation view
struct SuccessView: View {
    let message: String
    let onDismiss: (() -> Void)?

    @State private var show = false

    var body: some View {
        VStack(spacing: AppTheme.Layout.spacingLarge) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.success.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(AppTheme.Colors.success)
            }
            .scaleEffect(show ? 1.0 : 0.5)
            .opacity(show ? 1.0 : 0.0)

            Text(message)
                .font(AppTheme.Typography.sectionTitle)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(show ? 1.0 : 0.0)
        }
        .padding(AppTheme.Layout.paddingXLarge)
        .onAppear {
            withAnimation(AnimationConfig.bouncy.delay(0.2)) {
                show = true
            }

            if let onDismiss = onDismiss {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Loading States") {
    ScrollView {
        VStack(spacing: 32) {
            LoadingView(message: "Loading data...")

            SkeletonCard()

            ErrorView(
                message: "Could not connect to device. Please check your connection and try again.",
                retryAction: { print("Retry") }
            )

            EmptyStateView(
                icon: "heart.slash.fill",
                title: "No Data Available",
                message: "Connect your device to start monitoring your health data.",
                actionTitle: "Connect Device",
                action: { print("Connect") }
            )

            ConnectingView(deviceName: "ESP32-C3", connectionType: "BLE")

            SuccessView(message: "Successfully connected!", onDismiss: nil)
        }
        .padding()
    }
    .background(AppTheme.Colors.groupedBackground)
}
