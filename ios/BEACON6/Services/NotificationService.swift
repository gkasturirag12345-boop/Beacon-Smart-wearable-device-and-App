//
//  NotificationService.swift
//  BEACON
//
//  Created by Kasturiraj Guhan on 2/10/25.
//

import Foundation
import UserNotifications
import Combine

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    override private init() {
        super.init()
        checkAuthorizationStatus()
        // Set self as delegate to handle foreground notifications
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        do {
            // Note: .criticalAlert requires special entitlement from Apple
            // Using standard options for now: .alert, .sound, .badge
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await checkAuthorizationStatus()

            print("[NotificationService] Authorization granted: \(granted)")

            return granted
        } catch {
            print("[NotificationService] ❌ Failed to request notification authorization: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                authorizationStatus = settings.authorizationStatus
            }
        }
    }

    // MARK: - Heart Rate Alerts
    func sendHeartRateAlert(currentBPM: Double, baselineBPM: Double, variation: Double) {
        let content = UNMutableNotificationContent()

        // Special handling for heart stop (BPM = 0)
        if currentBPM == 0 {
            content.title = "🚨 HEART STOP ALERT"
            content.body = "No heartbeat detected! This is a critical emergency."
        } else {
            content.title = "⚠️ Heart Rate Alert"
            content.body = "Significant variation detected: \(Int(currentBPM)) BPM (baseline: \(Int(baselineBPM)) BPM)"
        }

        content.sound = .default
        content.categoryIdentifier = "HEART_RATE_ALERT"
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send heart rate alert: \(error)")
            }
        }
    }

    // MARK: - Fall Detection Alerts
    func sendFallDetectionAlert(impactMagnitude: Double, timestamp: Date) {
        let content = UNMutableNotificationContent()
        content.title = "🚨 FALL DETECTED!"
        content.body = "A fall has been detected. Impact: \(String(format: "%.2f", impactMagnitude)) m/s². Tap to respond."
        content.sound = .default
        content.categoryIdentifier = "FALL_ALERT"
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "fall-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send fall alert: \(error)")
            }
        }

        // Schedule follow-up alert if not acknowledged
        scheduleFollowUpFallAlert(after: 60) // 1 minute
    }

    private func scheduleFollowUpFallAlert(after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "🚨 URGENT: Fall Not Acknowledged"
        content.body = "Emergency services will be contacted if you don't respond."
        content.sound = .default
        content.categoryIdentifier = "FALL_FOLLOW_UP"
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: "fall-followup",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule follow-up alert: \(error)")
            }
        }
    }

    func cancelFallAlerts() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["fall-followup"]
        )
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["fall-followup"]
        )
    }

    // MARK: - Generic Notification Method
    func sendNotification(
        title: String,
        body: String,
        categoryIdentifier: String,
        threadIdentifier: String? = nil,
        interruptionLevel: UNNotificationInterruptionLevel = .timeSensitive
    ) {
        NSLog("[NotificationService] 📤 sendNotification called")
        NSLog("[NotificationService] Title: %@", title)
        NSLog("[NotificationService] Body: %@", body)
        NSLog("[NotificationService] Category: %@", categoryIdentifier)

        print("[NotificationService] 📤 Sending notification:")
        print("  Title: \(title)")
        print("  Category: \(categoryIdentifier)")
        print("  Interruption: \(interruptionLevel.rawValue)")

        // Check authorization status first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            NSLog("[NotificationService] Authorization status: %ld", settings.authorizationStatus.rawValue)
            NSLog("[NotificationService] Alert setting: %ld", settings.alertSetting.rawValue)

            if settings.authorizationStatus != .authorized {
                NSLog("[NotificationService] ⚠️ WARNING: Notifications not authorized!")
            }
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.interruptionLevel = interruptionLevel

        if let threadId = threadIdentifier {
            content.threadIdentifier = threadId
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        NSLog("[NotificationService] Adding notification request to UNUserNotificationCenter...")

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("[NotificationService] ❌ Failed to send notification: %@", error.localizedDescription)
                print("[NotificationService] ❌ Failed to send notification: \(error)")
            } else {
                NSLog("[NotificationService] ✅ Notification scheduled successfully (will fire in 1 second)")
                print("[NotificationService] ✅ Notification scheduled successfully")
            }
        }
    }

    // MARK: - Notification Categories
    func setupNotificationCategories() {
        // Heart Rate Alert Actions
        let heartRateViewAction = UNNotificationAction(
            identifier: "VIEW_HEART_RATE",
            title: "View Details",
            options: .foreground
        )
        let heartRateDismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )
        let heartRateCategory = UNNotificationCategory(
            identifier: "HEART_RATE_ALERT",
            actions: [heartRateViewAction, heartRateDismissAction],
            intentIdentifiers: [],
            options: []
        )

        // Fall Alert Actions
        let fallOKAction = UNNotificationAction(
            identifier: "FALL_OK",
            title: "I'm OK",
            options: [.foreground, .authenticationRequired]
        )
        let fallHelpAction = UNNotificationAction(
            identifier: "FALL_NEED_HELP",
            title: "Need Help",
            options: [.foreground, .authenticationRequired]
        )
        let fallCategory = UNNotificationCategory(
            identifier: "FALL_ALERT",
            actions: [fallOKAction, fallHelpAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Manual Alert Actions
        let manualCallHelpAction = UNNotificationAction(
            identifier: "CALL_HELP",
            title: "Call Emergency",
            options: [.foreground, .authenticationRequired]
        )
        let manualDismissAction = UNNotificationAction(
            identifier: "DISMISS_MANUAL",
            title: "Dismiss",
            options: []
        )
        let manualAlertCategory = UNNotificationCategory(
            identifier: "MANUAL_ALERT",
            actions: [manualCallHelpAction, manualDismissAction],
            intentIdentifiers: [],
            options: []
        )

        // False Alarm Category
        let falseAlarmCategory = UNNotificationCategory(
            identifier: "FALSE_ALARM",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        // SOS Alert Category
        let sosAlertCategory = UNNotificationCategory(
            identifier: "SOS_ALERT",
            actions: [manualCallHelpAction, manualDismissAction],
            intentIdentifiers: [],
            options: []
        )

        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([
            heartRateCategory,
            fallCategory,
            manualAlertCategory,
            falseAlarmCategory,
            sosAlertCategory
        ])
    }

    // MARK: - Badge Management
    func updateBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error = error {
                print("Failed to update badge count: \(error)")
            }
        }
    }

    func clearBadge() {
        updateBadgeCount(0)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    /// Handle notifications when app is in foreground
    /// This ensures critical alerts (fall, heart stop) are visible even when app is open
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let category = notification.request.content.categoryIdentifier

        // Show banner, sound, and badge for all alerts
        // Critical alerts (fall, heart stop) use .criticalAlert interruption level
        completionHandler([.banner, .sound, .badge])

        print("[NotificationService] Presenting foreground notification: \(category)")
    }

    /// Handle notification tap actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let category = response.notification.request.content.categoryIdentifier
        let actionId = response.actionIdentifier

        print("[NotificationService] User responded to notification: \(category), action: \(actionId)")

        switch actionId {
        case "FALL_OK":
            print("[NotificationService] User marked fall as OK")
            cancelFallAlerts()

        case "FALL_NEED_HELP":
            print("[NotificationService] User needs help - emergency response triggered")
            // Could trigger emergency contact here

        case UNNotificationDefaultActionIdentifier:
            // User tapped notification (no action button)
            print("[NotificationService] Notification tapped, opening app")

        default:
            break
        }

        completionHandler()
    }
}
