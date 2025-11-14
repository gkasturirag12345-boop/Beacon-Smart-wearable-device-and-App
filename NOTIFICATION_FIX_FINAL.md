# CRITICAL FIX: Notification Authorization Issue

**Date:** October 19, 2025
**Issue:** Manual alert and false alarm notifications not appearing on iPhone
**Root Cause:** App was requesting `.criticalAlert` permission without Apple entitlement

---

## ❗ Problem Identified

The app was requesting `.criticalAlert` notification permission in `NotificationService.swift:28`:

```swift
let granted = try await UNUserNotificationCenter.current().requestAuthorization(
    options: [.alert, .sound, .badge, .criticalAlert]  // ❌ PROBLEM
)
```

**Critical alerts require a special entitlement from Apple** that must be:
1. Requested through Apple Developer portal
2. Justified with a valid use case (medical emergencies, public safety)
3. Approved by Apple (can take weeks)

Without this entitlement:
- Authorization request may fail silently
- Notifications with `.critical` interruption level won't display
- No error is shown to the user

---

## ✅ Solution Applied

### 1. Fixed Authorization Request
**File:** `NotificationService.swift:25-41`

**Before:**
```swift
let granted = try await UNUserNotificationCenter.current().requestAuthorization(
    options: [.alert, .sound, .badge, .criticalAlert]
)
```

**After:**
```swift
// Note: .criticalAlert requires special entitlement from Apple
// Using standard options for now: .alert, .sound, .badge
let granted = try await UNUserNotificationCenter.current().requestAuthorization(
    options: [.alert, .sound, .badge]
)
print("[NotificationService] Authorization granted: \(granted)")
```

### 2. Changed Interruption Levels
Changed all notifications from `.critical` to `.timeSensitive`:

#### NotificationService.swift Changes:
- **Line 67:** Heart rate alerts - `.timeSensitive` (was `.critical`)
- **Line 65:** Heart rate sound - `.default` (was `.defaultCritical`)
- **Line 90:** Fall detection - `.timeSensitive` (was `.critical`)
- **Line 88:** Fall detection sound - `.default` (was `.defaultCritical`)
- **Line 115:** Follow-up fall alert - `.timeSensitive` (was `.critical`)
- **Line 113:** Follow-up sound - `.default` (was `.defaultCritical`)
- **Line 156:** Generic notification sound - `.default` (removed conditional)

#### AlertManager.swift Changes:
- **Line 330:** Manual alert - `.timeSensitive` (was `.critical`)

### 3. Interruption Level Comparison

| Level | Requires Entitlement | Bypasses DND | Description |
|-------|---------------------|--------------|-------------|
| `.passive` | ❌ No | ❌ No | Low priority, no sound |
| `.active` | ❌ No | ❌ No | Default notifications |
| `.timeSensitive` | ❌ No | ✅ Yes* | Important but not critical |
| `.critical` | ✅ **YES** | ✅ Yes | Medical/safety emergencies |

*Time-sensitive notifications can bypass Do Not Disturb if user enables "Time Sensitive Notifications" in Focus settings.

---

## 📱 What Changed for Users

### Before (Not Working):
- Authorization request failed silently
- Manual alerts didn't appear
- False alarms didn't appear
- Console showed alerts being processed

### After (Should Work):
- Standard notification authorization (will prompt user)
- Manual alerts appear as time-sensitive notifications
- False alarms appear as active notifications
- All notifications work in foreground, background, and locked states

---

## 🧪 Testing Instructions

### 1. Clean Build
```bash
# Clean DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/BEACON_5-*

# In Xcode
⌘ + Shift + K  # Clean Build Folder
⌘ + B          # Build
⌘ + R          # Run on device
```

### 2. Grant Permissions
- When app launches, tap **"Allow"** on notification permission prompt
- If you already denied: Settings → BEACON → Notifications → Allow Notifications ON

### 3. Test Notifications

**Manual Alert (Single Press):**
1. Press button once on ESP32-C3 (GPIO 7)
2. Should see: **"🚨 MANUAL ALERT"** notification
3. Console: `[NotificationService] 📤 Sending notification: MANUAL_ALERT`
4. Console: `[NotificationService] ✅ Notification scheduled successfully`

**False Alarm (Double Press):**
1. Press button twice quickly (within 1 second)
2. Should see: **"✅ False Alarm"** notification
3. Console: `[NotificationService] 📤 Sending notification: FALSE_ALARM`

### 4. Test Different States
- ✅ **Foreground** - App open, should show banner at top
- ✅ **Background** - App minimized, should show notification
- ✅ **Locked** - Phone locked, should show on lock screen

---

## 🔧 Console Logs to Watch

### Successful Notification Flow:
```
[AlertManager] ⚡️ [ALERT TRIGGERED] MANUAL_ALERT: ...
[NotificationService] 📤 Sending notification:
  Title: 🚨 MANUAL ALERT
  Category: MANUAL_ALERT
  Interruption: 2
[NotificationService] ✅ Notification scheduled successfully
[NotificationService] Presenting foreground notification: MANUAL_ALERT
```

### If Authorization Failed:
```
[NotificationService] Authorization granted: false
```
→ Check Settings → BEACON → Notifications

---

## 📊 All Notification Types & Levels

| Alert Type | Category | Interruption Level | Sound |
|-----------|----------|-------------------|-------|
| Heart Rate High/Low | `HEART_RATE_ALERT` | `.timeSensitive` | `.default` |
| Heart Stop | `HEART_RATE_ALERT` | `.timeSensitive` | `.default` |
| Fall Detected | `FALL_ALERT` | `.timeSensitive` | `.default` |
| Fall Follow-up | `FALL_FOLLOW_UP` | `.timeSensitive` | `.default` |
| **Manual Alert** | `MANUAL_ALERT` | `.timeSensitive` | `.default` |
| **False Alarm** | `FALSE_ALARM` | `.active` | `.default` |
| SOS Voice | `SOS_ALERT` | `.timeSensitive` | `.default` |

---

## 🚀 Future: Getting Critical Alert Entitlement

If you need true critical alerts (bypass DND, louder sound, full-screen):

### 1. Request Entitlement
- Go to Apple Developer portal
- Request "Time Sensitive Notifications" entitlement
- Justify use case (medical wearable for elderly/at-risk patients)

### 2. Add to Entitlements File
Create `BEACON.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.usernotifications.critical-alerts</key>
    <true/>
</dict>
</plist>
```

### 3. Update Code
After approval, change back to:
```swift
options: [.alert, .sound, .badge, .criticalAlert]
interruptionLevel: .critical
sound: .defaultCritical
```

---

## 📝 Files Modified

```
BEACON_iOS/BEACON/Services/
├── NotificationService.swift
│   ├── Line 25-41: Fixed authorization request
│   ├── Line 65-67: Heart rate alerts → .timeSensitive
│   ├── Line 88-90: Fall detection → .timeSensitive
│   ├── Line 113-115: Follow-up alerts → .timeSensitive
│   └── Line 156: Generic notification sound
└── AlertManager.swift
    └── Line 322-331: Manual alert → .timeSensitive
```

---

## ✅ Verification Checklist

- [x] Removed `.criticalAlert` from authorization request
- [x] Changed all `.critical` to `.timeSensitive`
- [x] Changed all `.defaultCritical` to `.default`
- [x] Added debug logging for authorization result
- [x] Maintained existing debug logs for notification sending
- [x] Documented critical alert entitlement process
- [ ] **USER: Test on device and verify notifications appear**

---

## 🐛 If Notifications Still Don't Appear

### Check Notification Settings:
```
iPhone Settings → BEACON → Notifications
```
Verify:
- ✅ Allow Notifications: ON
- ✅ Lock Screen: ON
- ✅ Notification Center: ON
- ✅ Banners: ON
- ✅ Sounds: ON
- ✅ Time Sensitive Notifications: ON (recommended)

### Check Focus/DND:
```
Settings → Focus → Do Not Disturb
```
Enable "Time Sensitive Notifications" to allow alerts during DND

### Check Console:
If you see:
```
[NotificationService] Authorization granted: false
```
→ Notification permissions were denied. Reset: Settings → General → Transfer or Reset iPhone → Reset Location & Privacy

---

**Status:** Ready for testing with standard notification permissions! 🎉

**Note:** This fix removes the critical alert requirement. Notifications will now work immediately without Apple approval, but won't have the full-screen critical alert behavior.
