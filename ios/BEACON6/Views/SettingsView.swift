//
//  SettingsView.swift
//  BEACON
//
//  Modern Settings View with Language Selection
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var showResetAlert = false
    @State private var showAboutSheet = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Layout.spacingXLarge) {
                    // App Header
                    headerSection

                    // Appearance Settings
                    appearanceSection

                    // Language Settings
                    languageSection

                    // Preferences
                    preferencesSection

                    // About Section
                    aboutSection

                    // Debug Section (Development)
                    #if DEBUG
                    debugSection
                    #endif

                    // Reset Button
                    resetSection
                }
                .padding(AppTheme.Layout.paddingLarge)
            }
            .background(AppTheme.Colors.groupedBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Reset Settings", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    HapticFeedback.warning()
                    settings.resetToDefaults()
                }
            } message: {
                Text("This will reset all settings to their default values.")
            }
            .sheet(isPresented: $showAboutSheet) {
                AboutView()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        ModernCard {
            VStack(spacing: AppTheme.Layout.spacingMedium) {
                // App Icon
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.bluetooth],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, AppTheme.Layout.paddingSmall)

                VStack(spacing: 4) {
                    Text(settings.appName)
                        .font(AppTheme.Typography.sectionTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text("Health Monitoring System")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    Text("Version \(settings.appVersion) (\(settings.buildNumber))")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                HStack {
                    Image(systemName: "paintbrush.fill")
                        .foregroundColor(AppTheme.Colors.primary)
                    Text("Appearance")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Spacer()
                }

                Divider()

                // Appearance Mode Picker
                VStack(spacing: AppTheme.Layout.spacingSmall) {
                    ForEach(AppearanceMode.allCases) { mode in
                        appearanceModeButton(mode: mode)
                    }
                }
            }
        }
    }

    private func appearanceModeButton(mode: AppearanceMode) -> some View {
        Button(action: {
            HapticFeedback.selection()
            withAnimation(AnimationConfig.smooth) {
                settings.appearanceMode = mode
            }
        }) {
            HStack(spacing: AppTheme.Layout.spacingMedium) {
                // Icon
                Image(systemName: mode.icon)
                    .font(.system(size: AppTheme.Layout.iconMedium))
                    .foregroundColor(settings.appearanceMode == mode ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        settings.appearanceMode == mode
                            ? AppTheme.Colors.primary.opacity(0.15)
                            : AppTheme.Colors.textSecondary.opacity(0.05)
                    )
                    .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

                // Label
                Text(mode.displayName)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()

                // Checkmark
                if settings.appearanceMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.success)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(AppTheme.Layout.paddingMedium)
            .background(
                settings.appearanceMode == mode
                    ? AppTheme.Colors.primary.opacity(0.05)
                    : Color.clear
            )
            .cornerRadius(AppTheme.Layout.cornerRadiusMedium)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Language Section

    private var languageSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(AppTheme.Colors.primary)
                    Text("Language")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Spacer()
                }

                Divider()

                // Language Options
                VStack(spacing: AppTheme.Layout.spacingSmall) {
                    ForEach(AppLanguage.allCases) { language in
                        languageButton(language: language)
                    }
                }
            }
        }
    }

    private func languageButton(language: AppLanguage) -> some View {
        Button(action: {
            HapticFeedback.selection()
            withAnimation(AnimationConfig.smooth) {
                settings.selectedLanguage = language
            }
        }) {
            HStack(spacing: AppTheme.Layout.spacingMedium) {
                // Flag
                Text(language.flag)
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .background(
                        settings.selectedLanguage == language
                            ? AppTheme.Colors.primary.opacity(0.15)
                            : AppTheme.Colors.textSecondary.opacity(0.05)
                    )
                    .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

                // Language Name
                Text(language.displayName)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()

                // Checkmark
                if settings.selectedLanguage == language {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.success)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(AppTheme.Layout.paddingMedium)
            .background(
                settings.selectedLanguage == language
                    ? AppTheme.Colors.primary.opacity(0.05)
                    : Color.clear
            )
            .cornerRadius(AppTheme.Layout.cornerRadiusMedium)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(AppTheme.Colors.primary)
                    Text("Preferences")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Spacer()
                }

                Divider()

                VStack(spacing: AppTheme.Layout.spacingSmall) {
                    // Notifications Toggle
                    ToggleRow(
                        icon: "bell.fill",
                        title: "Notifications",
                        description: "Receive health alerts and updates",
                        isOn: $settings.notificationsEnabled
                    )

                    // Haptic Feedback Toggle
                    ToggleRow(
                        icon: "iphone.radiowaves.left.and.right",
                        title: "Haptic Feedback",
                        description: "Feel vibrations on interactions",
                        isOn: $settings.hapticFeedbackEnabled
                    )
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(AppTheme.Colors.info)
                    Text("About")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Spacer()
                }

                Divider()

                VStack(spacing: AppTheme.Layout.spacingSmall) {
                    InfoRow(icon: "doc.text.fill", title: "Privacy Policy", action: {
                        HapticFeedback.light()
                        // Open privacy policy
                    })

                    InfoRow(icon: "shield.fill", title: "Terms of Service", action: {
                        HapticFeedback.light()
                        // Open terms
                    })

                    InfoRow(icon: "envelope.fill", title: "Contact Support", action: {
                        HapticFeedback.light()
                        // Open support email
                    })

                    InfoRow(icon: "heart.fill", title: "Rate the App", action: {
                        HapticFeedback.light()
                        // Open App Store
                    })
                }
            }
        }
    }

    // MARK: - Debug Section

    #if DEBUG
    private var debugSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                HStack {
                    Image(systemName: "ladybug.fill")
                        .foregroundColor(AppTheme.Colors.warning)
                    Text("Debug")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Spacer()
                    StatusBadge(text: "DEV", color: AppTheme.Colors.warning, style: .filled)
                }

                Divider()

                ToggleRow(
                    icon: "ant.fill",
                    title: "Debug Logs",
                    description: "Show detailed console logs",
                    isOn: $settings.debugLogsEnabled
                )
            }
        }
    }
    #endif

    // MARK: - Reset Section

    private var resetSection: some View {
        ModernButton(
            title: "Reset All Settings",
            icon: "arrow.counterclockwise",
            style: .destructive
        ) {
            HapticFeedback.warning()
            showResetAlert = true
        }
    }
}

// MARK: - Supporting Components

struct ToggleRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: AppTheme.Layout.spacingMedium) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: AppTheme.Layout.iconMedium))
                .foregroundColor(isOn ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                .frame(width: 44, height: 44)
                .background(
                    isOn
                        ? AppTheme.Colors.primary.opacity(0.15)
                        : AppTheme.Colors.textSecondary.opacity(0.05)
                )
                .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text(description)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()

            // Toggle
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppTheme.Colors.primary)
                .onChange(of: isOn) { _, _ in
                    HapticFeedback.selection()
                }
        }
        .padding(AppTheme.Layout.paddingMedium)
        .background(isOn ? AppTheme.Colors.primary.opacity(0.03) : Color.clear)
        .cornerRadius(AppTheme.Layout.cornerRadiusMedium)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Layout.spacingMedium) {
                Image(systemName: icon)
                    .font(.system(size: AppTheme.Layout.iconMedium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.Colors.textSecondary.opacity(0.1))
                    .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

                Text(title)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(AppTheme.Layout.paddingMedium)
            .background(Color.clear)
            .cornerRadius(AppTheme.Layout.cornerRadiusMedium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var settings = SettingsManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Layout.spacingXLarge) {
                    // App Icon
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary, AppTheme.Colors.bluetooth],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, AppTheme.Layout.paddingXLarge)

                    VStack(spacing: AppTheme.Layout.spacingSmall) {
                        Text(settings.appName)
                            .font(AppTheme.Typography.heroTitle)
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        Text("Health Monitoring System")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)

                        Text("Version \(settings.appVersion) (\(settings.buildNumber))")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }

                    ModernCard {
                        VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                            Text("About BEACON")
                                .font(AppTheme.Typography.cardTitle)
                                .foregroundColor(AppTheme.Colors.textPrimary)

                            Text("BEACON is a comprehensive health monitoring system that tracks heart rate, detects falls, and provides real-time alerts for elderly care and safety monitoring.")
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, AppTheme.Layout.paddingLarge)

                    VStack(spacing: AppTheme.Layout.spacingSmall) {
                        Text("Made with ❤️")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)

                        Text("© 2025 BEACON Project")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
                .padding(AppTheme.Layout.paddingLarge)
            }
            .background(AppTheme.Colors.groupedBackground)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
