// ============================================================================
// BUTTON NOTIFICATION FIX - CODE SNIPPETS
// ============================================================================
// Date: October 19, 2025
// Purpose: Complete implementation of button event notifications
// ============================================================================

// ============================================================================
// 1. BLEManager.swift - Callback Declarations
// ============================================================================
// Location: Line 37-43

// MARK: - Callbacks
var onHeartRateReceived: ((Double) -> Void)?
var onFallDetected: ((Double, String?) -> Void)?
var onSleepDataReceived: ((Double, Double) -> Void)?
var onSOSAlertReceived: (() -> Void)?
var onFalseAlarmReceived: (() -> Void)?  // ✅ NEW: False alarm callback
var onWearStatusReceived: ((WearStatus) -> Void)?

// ============================================================================
// 2. BLEManager.swift - Alert String Parsing
// ============================================================================
// Location: Line 410-448

private func parseAlertString(from data: Data) {
    // Parse text string alerts from firmware
    guard let alertString = String(data: data, encoding: .utf8) else {
        print("[BLE] Failed to decode alert string")
        return
    }

    print("[BLE RX] 🚨 Alert String: \"\(alertString)\"")

    // Handle different alert types
    switch alertString {
    case "FALL_DETECTED":
        print("[BLE RX] ✅ FALL DETECTED!")
        onFallDetected?(2.5, nil)

    case "HEART_STOP":
        print("[BLE RX] ✅ HEART STOP ALERT!")
        onHeartRateReceived?(0)

    case "MANUAL_ALERT":
        print("[BLE RX] ✅ MANUAL ALERT (Single Button Press)")
        onSOSAlertReceived?()  // ✅ Trigger manual alert notification

    case "FALSE_ALARM":
        print("[BLE RX] ✅ FALSE ALARM (Double Button Press)")
        onFalseAlarmReceived?()  // ✅ NEW: Trigger false alarm notification

    case "DEVICE_WORN":
        print("[BLE RX] ✅ Device worn status: WORN")
        onWearStatusReceived?(.worn)

    case "DEVICE_NOT_WORN":
        print("[BLE RX] ✅ Device worn status: NOT WORN")
        onWearStatusReceived?(.notWorn)

    default:
        print("[BLE RX] ⚠️ Unknown alert type: \(alertString)")
    }
}

// ============================================================================
// 3. HealthMonitoringService.swift - Callback Handlers
// ============================================================================
// Location: Line 136-153

// Manual alert callback (single button press)
bleManager.onSOSAlertReceived = { [weak self] in
    print("[HealthMonitoringService] 🚨 MANUAL ALERT - Button Pressed!")

    self?.alertManager.triggerManualAlert(
        message: "Emergency button pressed on wearable device!",
        severity: .critical
    )
}

// False alarm callback (double button press) ✅ NEW
bleManager.onFalseAlarmReceived = { [weak self] in
    print("[HealthMonitoringService] ✅ FALSE ALARM - Double Button Press!")

    self?.alertManager.triggerFalseAlarm(
        message: "Alert cancelled by user (double button press)"
    )
}

// ============================================================================
// 4. AlertManager.swift - Alert Type Enum
// ============================================================================
// Location: Line 13-26

enum AlertType: String, Codable {
    case heartRateHigh = "HEART_RATE_HIGH"
    case heartRateLow = "HEART_RATE_LOW"
    case heartStop = "HEART_STOP"
    case fallDetected = "FALL_DETECTED"
    case manualAlert = "MANUAL_ALERT"      // ✅ Used for notifications
    case falseAlarm = "FALSE_ALARM"        // ✅ Used for notifications
    case deviceWorn = "DEVICE_WORN"
    case deviceNotWorn = "DEVICE_NOT_WORN"
    case deviceDisconnected = "DEVICE_DISCONNECTED"
    case manual = "MANUAL"                 // ⚠️ Legacy, not used
    case sosVoiceDetected = "SOS_VOICE_DETECTED"
}

// ============================================================================
// 5. AlertManager.swift - Manual Alert Functions
// ============================================================================
// Location: Line 175-193

// MARK: - Manual Alerts

/// Create manual alert (button press alert)
func triggerManualAlert(message: String, severity: AlertSeverity = .medium) {
    triggerAlert(
        type: .manualAlert,  // ✅ FIXED: Was .manual, now .manualAlert
        message: message,
        severity: severity,
        value: nil
    )
}

/// Create false alarm notification (double button press) ✅ NEW
func triggerFalseAlarm(message: String = "Alert cancelled by user (double button press)") {
    triggerAlert(
        type: .falseAlarm,
        message: message,
        severity: .low,
        value: nil
    )
}

// ============================================================================
// 6. AlertManager.swift - Notification Sending (Switch Statement)
// ============================================================================
// Location: Line 300-358

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

    case .manualAlert:  // ✅ Now matches the alert type!
        // Manual alert from button press - send time-sensitive notification
        notificationService.sendNotification(
            title: "🚨 MANUAL ALERT",
            body: "Emergency button pressed on wearable device!",
            categoryIdentifier: "MANUAL_ALERT",
            threadIdentifier: "manual-alert",
            interruptionLevel: .timeSensitive
        )

    case .falseAlarm:  // ✅ NEW: False alarm notification
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
        notificationService.sendNotification(
            title: "🚨 SOS Voice Detected",
            body: alert.message,
            categoryIdentifier: "SOS_ALERT",
            threadIdentifier: "sos-voice"
        )
    }
}

// ============================================================================
// 7. NotificationService.swift - Generic Notification Method
// ============================================================================
// Location: Line 136-173

/// Generic notification sender with full control
func sendNotification(
    title: String,
    body: String,
    categoryIdentifier: String,
    threadIdentifier: String? = nil,
    interruptionLevel: UNNotificationInterruptionLevel = .timeSensitive
) {
    print("[NotificationService] 📤 Sending notification:")
    print("  Title: \(title)")
    print("  Category: \(categoryIdentifier)")
    print("  Interruption: \(interruptionLevel.rawValue)")

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

    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("[NotificationService] ❌ Failed to send notification: \(error)")
        } else {
            print("[NotificationService] ✅ Notification scheduled successfully")
        }
    }
}

// ============================================================================
// 8. NotificationService.swift - Notification Categories
// ============================================================================
// Location: Line 176-254

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

    // Manual Alert Actions ✅ Button Press
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

    // False Alarm Category ✅ Double Button Press
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
        manualAlertCategory,  // ✅ Button press
        falseAlarmCategory,   // ✅ Double press
        sosAlertCategory
    ])
}

// ============================================================================
// 9. BEACONApp.swift - App Initialization
// ============================================================================
// Location: Line 10-27

@main
struct BEACONApp: App {
    // Initialize notification service on app launch
    init() {
        // Request notification authorization
        Task {
            await NotificationService.shared.requestAuthorization()
        }
        // Setup notification categories
        NotificationService.shared.setupNotificationCategories()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// ============================================================================
// 10. NotificationService.swift - Delegate Setup
// ============================================================================
// Location: Line 17-22

override private init() {
    super.init()
    checkAuthorizationStatus()
    // Set self as delegate to handle foreground notifications
    UNUserNotificationCenter.current().delegate = self
}

// ============================================================================
// 11. NotificationService.swift - Foreground Presentation
// ============================================================================
// Location: Line 272-287

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Handle notifications when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let category = notification.request.content.categoryIdentifier

        // Show banner, sound, and badge for all alerts
        completionHandler([.banner, .sound, .badge])

        print("[NotificationService] Presenting foreground notification: \(category)")
    }
}

// ============================================================================
// COMPLETE EVENT FLOW DIAGRAM
// ============================================================================

/*
SINGLE BUTTON PRESS (MANUAL_ALERT):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ESP32-C3 Firmware (beacon5.ino)
    │  GPIO 7 button pressed once
    │  Detects single press (not double)
    │  Sends BLE characteristic: "MANUAL_ALERT"
    ↓
BLEManager.swift (peripheral:didUpdateValueFor:)
    │  Receives BLE data on alertCharacteristicUUID
    │  Calls parseAlertString(from: data)
    │  Case "MANUAL_ALERT" matched
    │  Triggers: onSOSAlertReceived?()
    ↓
HealthMonitoringService.swift (onSOSAlertReceived callback)
    │  Receives callback
    │  Calls: alertManager.triggerManualAlert()
    ↓
AlertManager.swift (triggerManualAlert)
    │  Creates HealthAlert with type: .manualAlert ✅
    │  Calls: triggerAlert(..., type: .manualAlert)
    │  Adds to activeAlerts and alertHistory
    │  Calls: sendNotification(for: alert)
    ↓
AlertManager.swift (sendNotification)
    │  Switch on alert.type
    │  Case .manualAlert matched ✅
    │  Calls: notificationService.sendNotification(
    │      title: "🚨 MANUAL ALERT",
    │      body: "Emergency button pressed on wearable device!",
    │      categoryIdentifier: "MANUAL_ALERT",
    │      interruptionLevel: .timeSensitive
    │  )
    ↓
NotificationService.swift (sendNotification)
    │  Creates UNMutableNotificationContent
    │  Sets title, body, sound, category, interruption level
    │  Creates UNNotificationRequest with 1-second trigger
    │  Adds to UNUserNotificationCenter
    │  Prints: "✅ Notification scheduled successfully"
    ↓
UNUserNotificationCenter
    │  Schedules notification
    │  Calls delegate: willPresent notification
    ↓
NotificationService.swift (willPresent)
    │  Calls completionHandler([.banner, .sound, .badge])
    ↓
iOS Notification System
    │  Shows notification banner
    │  Plays sound
    │  Updates badge
    ✓  User sees: "🚨 MANUAL ALERT"


DOUBLE BUTTON PRESS (FALSE_ALARM):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ESP32-C3 Firmware (beacon5.ino)
    │  GPIO 7 button pressed twice within 1 second
    │  Detects double press
    │  Sends BLE characteristic: "FALSE_ALARM"
    ↓
BLEManager.swift (peripheral:didUpdateValueFor:)
    │  Receives BLE data on alertCharacteristicUUID
    │  Calls parseAlertString(from: data)
    │  Case "FALSE_ALARM" matched
    │  Triggers: onFalseAlarmReceived?() ✅ NEW
    ↓
HealthMonitoringService.swift (onFalseAlarmReceived callback) ✅ NEW
    │  Receives callback
    │  Calls: alertManager.triggerFalseAlarm()
    ↓
AlertManager.swift (triggerFalseAlarm) ✅ NEW
    │  Creates HealthAlert with type: .falseAlarm
    │  Calls: triggerAlert(..., type: .falseAlarm)
    │  Adds to activeAlerts and alertHistory
    │  Calls: sendNotification(for: alert)
    ↓
AlertManager.swift (sendNotification)
    │  Switch on alert.type
    │  Case .falseAlarm matched
    │  Calls: notificationService.sendNotification(
    │      title: "✅ False Alarm",
    │      body: "Alert cancelled by user (double button press)",
    │      categoryIdentifier: "FALSE_ALARM",
    │      interruptionLevel: .active
    │  )
    ↓
NotificationService.swift (sendNotification)
    │  Creates UNMutableNotificationContent
    │  Sets title, body, sound, category, interruption level
    │  Creates UNNotificationRequest with 1-second trigger
    │  Adds to UNUserNotificationCenter
    │  Prints: "✅ Notification scheduled successfully"
    ↓
UNUserNotificationCenter
    │  Schedules notification
    │  Calls delegate: willPresent notification
    ↓
NotificationService.swift (willPresent)
    │  Calls completionHandler([.banner, .sound, .badge])
    ↓
iOS Notification System
    │  Shows notification banner
    │  Plays sound
    │  Updates badge
    ✓  User sees: "✅ False Alarm"
*/
