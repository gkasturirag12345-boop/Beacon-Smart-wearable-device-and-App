//
//  AlertManager.swift
//  BEACON
//
//  Native iOS Alert Management System
//  Manages alert logic, notifications, and alert lifecycle entirely on device
//

import Foundation
import Combine
import UserNotifications

/// Alert types supported by the system
enum AlertType: String, Codable {
    case heartRateHigh = "HEART_RATE_HIGH"
    case heartRateLow = "HEART_RATE_LOW"
    case heartStop = "HEART_STOP"
    case fallDetected = "FALL_DETECTED"
    case manualAlert = "MANUAL_ALERT"
    case falseAlarm = "FALSE_ALARM"
    case deviceWorn = "DEVICE_WORN"
    case deviceNotWorn = "DEVICE_NOT_WORN"
    case deviceDisconnected = "DEVICE_DISCONNECTED"
    case manual = "MANUAL"
    case sosVoiceDetected = "SOS_VOICE_DETECTED"
}

/// Alert severity levels
enum AlertSeverity: String, Codable {
    case low, medium, high, critical
}

/// Wear detection status
enum WearStatus: String, Codable {
    case worn = "WORN"
    case notWorn = "NOT_WORN"
    case unknown = "UNKNOWN"
}

/// Health alert model
struct HealthAlert: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: AlertType
    let message: String
    let severity: AlertSeverity
    var resolved: Bool
    var resolvedAt: Date?
    let value: Double?
    let metadata: [String: String]?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: AlertType,
        message: String,
        severity: AlertSeverity,
        resolved: Bool = false,
        resolvedAt: Date? = nil,
        value: Double? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.message = message
        self.severity = severity
        self.resolved = resolved
        self.resolvedAt = resolvedAt
        self.value = value
        self.metadata = metadata
    }
}

/// Alert Manager - Handles all alert logic and notifications
class AlertManager: ObservableObject {
    static let shared = AlertManager()

    // MARK: - Published Properties
    @Published var activeAlerts: [HealthAlert] = []
    @Published var alertHistory: [HealthAlert] = []

    // MARK: - Configuration
    private let heartRateLowThreshold: Double = 40
    private let heartRateHighThreshold: Double = 120
    private let fallDetectionThreshold: Double = 2.5
    private let alertCooldownPeriod: TimeInterval = 30 // 30 seconds

    // MARK: - Private State
    private var alertCooldowns: [AlertType: Date] = [:]
    private let notificationService = NotificationService.shared
    private let maxHistorySize = 50

    private init() {
        print("[AlertManager] Initialized")
    }

    // MARK: - Public Alert Methods

    /// Trigger SOS voice detection alert (public API for KeywordSpotter)
    func triggerSOSVoiceAlert(confidence: Double, detectionTime: String? = nil, latencyMs: Double? = nil) {
        NSLog("[AlertManager] 🚨 triggerSOSVoiceAlert called with confidence: %.3f", confidence)

        var message = "SOS keyword detected with \(String(format: "%.1f", confidence * 100))% confidence"
        if let time = detectionTime {
            message += " at \(time)"
        }
        if let latency = latencyMs {
            message += " (latency: \(String(format: "%.0f", latency))ms)"
        }

        var metadata: [String: String] = ["source": "voice_detection"]
        if let time = detectionTime {
            metadata["detectionTime"] = time
        }
        if let latency = latencyMs {
            metadata["latencyMs"] = String(format: "%.1f", latency)
        }

        triggerAlert(
            type: .sosVoiceDetected,
            message: message,
            severity: .critical,
            value: confidence,
            metadata: metadata
        )
    }

    // MARK: - Heart Rate Monitoring

    /// Process heart rate data and check for alerts
    /// Heart stop alerts are safety-critical and trigger regardless of wear status
    func processHeartRate(_ bpm: Double, wearStatus: WearStatus) {
        // Check for low heart rate
        if bpm < heartRateLowThreshold {
            print("[AlertManager] ⚠️ Low heart rate detected: \(Int(bpm)) BPM (threshold: <\(Int(heartRateLowThreshold)))")
            triggerAlert(
                type: .heartRateLow,
                message: "Low heart rate detected: \(Int(bpm)) BPM",
                severity: .high,
                value: bpm
            )
        }

        // Check for high heart rate
        else if bpm > heartRateHighThreshold {
            print("[AlertManager] ⚠️ High heart rate detected: \(Int(bpm)) BPM (threshold: >\(Int(heartRateHighThreshold)))")
            triggerAlert(
                type: .heartRateHigh,
                message: "High heart rate detected: \(Int(bpm)) BPM",
                severity: .high,
                value: bpm
            )
        }
    }

    // MARK: - Fall Detection

    /// Process motion data and check for fall detection
    /// Fall detection is safety-critical and triggers regardless of wear status
    func processMotion(magnitude: Double, wearStatus: WearStatus) {
        print("[AlertManager] processMotion called - magnitude: \(String(format: "%.2f", magnitude)) G, threshold: \(fallDetectionThreshold)")

        // Check for fall (high impact) - FIXED: >= instead of > to include threshold value
        if magnitude >= fallDetectionThreshold {
            print("[AlertManager] ✅ Fall threshold met - triggering alert")
            triggerAlert(
                type: .fallDetected,
                message: "Fall detected! Impact magnitude: \(String(format: "%.2f", magnitude)) G",
                severity: .critical,
                value: magnitude
            )
        } else {
            print("[AlertManager] ❌ Fall threshold NOT met - no alert triggered")
        }
    }

    // MARK: - Device Status

    /// Trigger alert for device disconnection
    func processDeviceDisconnection() {
        triggerAlert(
            type: .deviceDisconnected,
            message: "Health monitor device disconnected",
            severity: .medium,
            value: nil
        )
    }

    // MARK: - Manual Alerts

    /// Create manual alert (button press alert)
    func triggerManualAlert(message: String, severity: AlertSeverity = .medium) {
        triggerAlert(
            type: .manualAlert,  // FIXED: Use .manualAlert for button press notifications
            message: message,
            severity: severity,
            value: nil
        )
    }

    /// Create false alarm notification (double button press)
    func triggerFalseAlarm(message: String = "Alert cancelled by user (double button press)") {
        triggerAlert(
            type: .falseAlarm,
            message: message,
            severity: .low,
            value: nil
        )
    }

    // MARK: - Core Alert Logic

    /// Core alert triggering logic with cooldown prevention
    private func triggerAlert(
        type: AlertType,
        message: String,
        severity: AlertSeverity,
        value: Double?,
        metadata: [String: String]? = nil
    ) {
        NSLog("[AlertManager] triggerAlert called - type: %@, message: %@", type.rawValue, message)

        // Check cooldown to prevent alert spam
        if isInCooldown(type: type) {
            NSLog("[AlertManager] ⏸️ Alert %@ in cooldown, skipping", type.rawValue)
            print("[AlertManager] Alert \(type.rawValue) in cooldown, skipping")
            return
        }

        NSLog("[AlertManager] Creating alert...")

        // Create alert
        let alert = HealthAlert(
            type: type,
            message: message,
            severity: severity,
            value: value,
            metadata: metadata
        )

        // Add to active alerts
        DispatchQueue.main.async { [weak self] in
            self?.activeAlerts.append(alert)
            self?.addToHistory(alert)
            NSLog("[AlertManager] Alert added to activeAlerts list")
        }

        // Set cooldown
        setCooldown(for: type)
        NSLog("[AlertManager] Cooldown set for %@", type.rawValue)

        // Send notification
        NSLog("[AlertManager] Calling sendNotification...")
        sendNotification(for: alert)

        // Log alert
        let severityEmoji = getSeverityEmoji(severity)
        print("\(severityEmoji) [ALERT TRIGGERED] \(type.rawValue): \(message)")
        NSLog("[AlertManager] ✅ Alert triggered successfully")
    }

    // MARK: - Cooldown Management

    /// Check if alert type is in cooldown period
    private func isInCooldown(type: AlertType) -> Bool {
        guard let lastTrigger = alertCooldowns[type] else {
            return false
        }

        let elapsed = Date().timeIntervalSince(lastTrigger)
        return elapsed < alertCooldownPeriod
    }

    /// Set cooldown for alert type
    private func setCooldown(for type: AlertType) {
        alertCooldowns[type] = Date()
    }

    /// Clear cooldown for specific alert type
    func clearCooldown(for type: AlertType) {
        alertCooldowns.removeValue(forKey: type)
    }

    // MARK: - Alert Management

    /// Resolve an alert
    func resolveAlert(_ alertId: UUID) {
        if let index = activeAlerts.firstIndex(where: { $0.id == alertId }) {
            var alert = activeAlerts[index]
            alert.resolved = true
            alert.resolvedAt = Date()

            DispatchQueue.main.async { [weak self] in
                self?.activeAlerts[index] = alert

                // Update history
                if let historyIndex = self?.alertHistory.firstIndex(where: { $0.id == alertId }) {
                    self?.alertHistory[historyIndex] = alert
                }
            }

            print("[AlertManager] Resolved alert: \(alertId)")
        }
    }

    /// Delete an alert
    func deleteAlert(_ alertId: UUID) {
        DispatchQueue.main.async { [weak self] in
            self?.activeAlerts.removeAll { $0.id == alertId }
        }
        print("[AlertManager] Deleted alert: \(alertId)")
    }

    /// Clear all resolved alerts
    func clearResolvedAlerts() {
        DispatchQueue.main.async { [weak self] in
            self?.activeAlerts.removeAll { $0.resolved }
        }
        print("[AlertManager] Cleared all resolved alerts")
    }

    /// Add alert to history
    private func addToHistory(_ alert: HealthAlert) {
        alertHistory.insert(alert, at: 0)

        // Trim history to max size
        if alertHistory.count > maxHistorySize {
            alertHistory = Array(alertHistory.prefix(maxHistorySize))
        }
    }

    // MARK: - Notifications

    /// Send iOS notification for alert
    private func sendNotification(for alert: HealthAlert) {
        switch alert.type {
        case .heartRateHigh, .heartRateLow:
            notificationService.sendHeartRateAlert(
                currentBPM: alert.value ?? 0,
                baselineBPM: 75.0,
                variation: abs((alert.value ?? 75.0) - 75.0)
            )

        case .heartStop:
            notificationService.sendHeartRateAlert(
                currentBPM: 0,
                baselineBPM: 75.0,
                variation: 75.0
            )

        case .fallDetected:
            notificationService.sendFallDetectionAlert(
                impactMagnitude: alert.value ?? 0,
                timestamp: alert.timestamp
            )

        case .manualAlert:
            // Manual alert from button press - send time-sensitive notification
            // Note: .critical requires Apple entitlement, using .timeSensitive instead
            notificationService.sendNotification(
                title: "🚨 MANUAL ALERT",
                body: "Emergency button pressed on wearable device!",
                categoryIdentifier: "MANUAL_ALERT",
                threadIdentifier: "manual-alert",
                interruptionLevel: .timeSensitive
            )

        case .falseAlarm:
            // False alarm cancellation - send notification to confirm
            notificationService.sendNotification(
                title: "✅ False Alarm",
                body: "Alert cancelled by user (double button press)",
                categoryIdentifier: "FALSE_ALARM",
                threadIdentifier: "false-alarm",
                interruptionLevel: .active
            )

        case .deviceWorn, .deviceNotWorn:
            // Wear status changes - no notification needed
            break

        case .deviceDisconnected, .manual:
            // Could add custom notifications for these types
            break

        case .sosVoiceDetected:
            // SOS voice detection - send critical alert
            NSLog("[AlertManager] Sending SOS notification - title: '🚨 SOS Voice Detected', body: '%@'", alert.message)
            notificationService.sendNotification(
                title: "🚨 SOS Voice Detected",
                body: alert.message,
                categoryIdentifier: "SOS_ALERT",
                threadIdentifier: "sos-voice"
            )
            NSLog("[AlertManager] SOS notification sent to NotificationService")
        }
    }

    // MARK: - Statistics

    /// Get alert statistics
    func getAlertStats() -> AlertStatistics {
        let total = alertHistory.count
        let unresolved = activeAlerts.filter { !$0.resolved }.count
        let resolved = alertHistory.filter { $0.resolved }.count

        var byType: [AlertType: Int] = [:]
        var bySeverity: [AlertSeverity: Int] = [:]

        for alert in alertHistory {
            byType[alert.type, default: 0] += 1
            bySeverity[alert.severity, default: 0] += 1
        }

        return AlertStatistics(
            total: total,
            unresolved: unresolved,
            resolved: resolved,
            byType: byType,
            bySeverity: bySeverity
        )
    }

    /// Get unresolved alerts
    func getUnresolvedAlerts() -> [HealthAlert] {
        return activeAlerts.filter { !$0.resolved }
    }

    // MARK: - Helpers

    private func getSeverityEmoji(_ severity: AlertSeverity) -> String {
        switch severity {
        case .critical: return "🚨"
        case .high: return "⚠️"
        case .medium: return "⚡️"
        case .low: return "ℹ️"
        }
    }
}

// MARK: - Statistics Model

struct AlertStatistics {
    let total: Int
    let unresolved: Int
    let resolved: Int
    let byType: [AlertType: Int]
    let bySeverity: [AlertSeverity: Int]
}
