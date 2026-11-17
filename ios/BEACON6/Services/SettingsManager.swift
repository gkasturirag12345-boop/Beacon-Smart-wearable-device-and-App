//
//  SettingsManager.swift
//  BEACON
//
//  Manages app settings and user preferences
//

import Foundation
import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - Published Properties

    @Published var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: Keys.language)
            // Update app language
            applyLanguage()
        }
    }

    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: Keys.appearance)
            applyAppearance()
        }
    }

    @Published var debugLogsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(debugLogsEnabled, forKey: Keys.debugLogs)
        }
    }

    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notifications)
        }
    }

    @Published var hapticFeedbackEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticFeedbackEnabled, forKey: Keys.hapticFeedback)
        }
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let language = "app_language"
        static let appearance = "app_appearance"
        static let debugLogs = "debug_logs_enabled"
        static let notifications = "notifications_enabled"
        static let hapticFeedback = "haptic_feedback_enabled"
    }

    // MARK: - Initialization

    private init() {
        // Load saved preferences or use defaults
        let languageRaw = UserDefaults.standard.string(forKey: Keys.language) ?? AppLanguage.english.rawValue
        self.selectedLanguage = AppLanguage(rawValue: languageRaw) ?? .english

        let appearanceRaw = UserDefaults.standard.string(forKey: Keys.appearance) ?? AppearanceMode.system.rawValue
        self.appearanceMode = AppearanceMode(rawValue: appearanceRaw) ?? .system

        self.debugLogsEnabled = UserDefaults.standard.bool(forKey: Keys.debugLogs)
        self.notificationsEnabled = UserDefaults.standard.object(forKey: Keys.notifications) as? Bool ?? true
        self.hapticFeedbackEnabled = UserDefaults.standard.object(forKey: Keys.hapticFeedback) as? Bool ?? true

        // Apply language setting (appearance will be applied when user changes it)
        applyLanguage()
    }

    // MARK: - Apply Settings

    private func applyLanguage() {
        // Set app language
        UserDefaults.standard.set([selectedLanguage.code], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        print("📱 [SettingsManager] Language changed to: \(selectedLanguage.displayName)")
    }

    private func applyAppearance() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }

            switch self.appearanceMode {
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
            }

            print("📱 [SettingsManager] Appearance changed to: \(self.appearanceMode.displayName)")
        }
    }

    // MARK: - App Info

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "BEACON"
    }

    // MARK: - Reset Settings

    func resetToDefaults() {
        selectedLanguage = .english
        appearanceMode = .system
        debugLogsEnabled = false
        notificationsEnabled = true
        hapticFeedbackEnabled = true

        print("📱 [SettingsManager] Settings reset to defaults")
    }
}

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case chinese = "zh"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        }
    }

    var code: String {
        rawValue
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        }
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}
