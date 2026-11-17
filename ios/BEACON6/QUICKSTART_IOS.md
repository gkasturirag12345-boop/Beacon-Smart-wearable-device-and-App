# BEACON iOS - Quick Start

## 🎯 What Just Happened?

You now have a **fully self-contained iOS health monitoring app** that runs 100% on your iPhone!

**No computer needed!** ✨

---

## 📁 New Files Created

Located in `/Users/kasturirajguhan/Downloads/Beacon3/BEACON/Services/`:

1. **`AlertManager.swift`** - Smart alerts with wear detection
2. **`DataStore.swift`** - In-memory data storage
3. **`TestSimulator.swift`** - Test mode for development
4. **`HealthMonitoringService.swift`** - Main coordinator

---

## 🚀 Quick Setup (3 Steps)

### Step 1: Add Files to Xcode
1. Open `BEACON_2.xcodeproj` in Xcode
2. Drag these 4 files into your `Services` folder:
   - AlertManager.swift
   - DataStore.swift
   - TestSimulator.swift
   - HealthMonitoringService.swift

### Step 2: Update ContentView.swift
```swift
// Replace this line:
@StateObject private var apiService = DeviceAPIService()

// With this:
@StateObject private var healthService = HealthMonitoringService.shared
```

### Step 3: Remove Old Files (Optional but recommended)
- Delete `HTTPServerManager.swift`
- Delete `DeviceAPIService+Server.swift`
- Remove Vapor dependency

**That's it!** Build and run! 🎉

---

## 🧪 Test It!

### Enable Test Mode (No Hardware):
```swift
let healthService = HealthMonitoringService.shared
healthService.enableTestMode()
```

You'll see:
- ✅ Heart rate updating every 2 seconds (60-120 BPM)
- ✅ Wear status toggling every 10 seconds
- ✅ Random alerts (heart rate, fall detection)
- ✅ All features work without ESP32!

### Connect to Real Device:
```swift
healthService.startBLEScanning()
// Select your ESP32 device
healthService.connect(to: selectedPeripheral)
```

---

## 💻 Basic Usage

### In Your Views:
```swift
import SwiftUI

struct MyView: View {
    @EnvironmentObject var healthService: HealthMonitoringService

    var body: some View {
        VStack {
            // Show heart rate
            if let hr = healthService.currentHeartRate {
                Text("\(Int(hr)) BPM")
                    .font(.largeTitle)
            }

            // Show connection status
            Text(healthService.connectionStatus)
                .foregroundColor(healthService.isConnected ? .green : .red)

            // Show alerts
            List(healthService.activeAlerts) { alert in
                Text(alert.message)
            }

            // Control buttons
            Button(healthService.isTestMode ? "Stop Test" : "Start Test") {
                if healthService.isTestMode {
                    healthService.disableTestMode()
                } else {
                    healthService.enableTestMode()
                }
            }
        }
    }
}
```

---

## 🔌 Available Methods

### Connection
```swift
healthService.startBLEScanning()           // Scan for devices
healthService.stopBLEScanning()            // Stop scanning
healthService.connect(to: peripheral)      // Connect to device
healthService.disconnect()                 // Disconnect
```

### Test Mode
```swift
healthService.enableTestMode()            // Enable simulator
healthService.disableTestMode()           // Disable simulator
healthService.triggerTestHeartRateHigh()  // Test high HR alert
healthService.triggerTestHeartRateLow()   // Test low HR alert
healthService.triggerTestFall()           // Test fall detection
```

### Data Access
```swift
healthService.getCurrentHeartRate()       // Get latest HR
healthService.getHeartRateHistory()       // Get HR history
healthService.getFallDetectionStatus()    // Check for falls
healthService.getAlerts()                 // Get all alerts
```

### Alert Management
```swift
healthService.resolveAlert(alertId)       // Mark alert as resolved
healthService.deleteAlert(alertId)        // Delete alert
healthService.clearResolvedAlerts()       // Clear old alerts
```

### Status
```swift
healthService.isConnected                 // Bool: connected?
healthService.isTestMode                  // Bool: test mode?
healthService.connectionStatus            // String: status
healthService.currentHeartRate            // Double?: latest HR
healthService.currentWearStatus           // WearStatus enum
healthService.activeAlerts                // [HealthAlert]
```

---

## 📊 Data Models

### HealthAlert
```swift
struct HealthAlert {
    let id: UUID
    let timestamp: Date
    let type: AlertType              // .heartRateHigh, .heartRateLow, .fallDetected
    let message: String
    let severity: AlertSeverity      // .low, .medium, .high, .critical
    var resolved: Bool
    let value: Double?
}
```

### WearStatus
```swift
enum WearStatus {
    case worn          // Device is worn
    case notWorn       // Device not worn
    case unknown       // Status unknown
}
```

### AlertType
```swift
enum AlertType {
    case heartRateHigh
    case heartRateLow
    case fallDetected
    case deviceDisconnected
    case manual
}
```

---

## 🎨 Example Views

### Dashboard with Heart Rate
```swift
struct DashboardView: View {
    @EnvironmentObject var healthService: HealthMonitoringService

    var body: some View {
        VStack(spacing: 30) {
            // Connection Status
            HStack {
                Circle()
                    .fill(healthService.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Text(healthService.connectionStatus)
            }

            // Heart Rate Display
            VStack {
                Text("HEART RATE")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let hr = healthService.currentHeartRate {
                    Text("\(Int(hr))")
                        .font(.system(size: 72, weight: .bold))
                    Text("BPM")
                        .font(.caption)
                } else {
                    Text("--")
                        .font(.system(size: 72, weight: .bold))
                }
            }

            // Wear Status
            HStack {
                Image(systemName: "applewatch")
                Text(healthService.currentWearStatus.rawValue)
            }
            .foregroundColor(
                healthService.currentWearStatus == .worn ? .green : .orange
            )
        }
    }
}
```

### Alert List
```swift
struct AlertsView: View {
    @EnvironmentObject var healthService: HealthMonitoringService

    var body: some View {
        List {
            ForEach(healthService.activeAlerts.filter { !$0.resolved }) { alert in
                VStack(alignment: .leading) {
                    HStack {
                        Text(severityIcon(alert.severity))
                        Text(alert.message)
                            .font(.headline)
                    }

                    Text(alert.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .swipeActions {
                    Button("Resolve") {
                        healthService.resolveAlert(alert.id)
                    }
                    .tint(.green)
                }
            }
        }
        .navigationTitle("Active Alerts")
    }

    func severityIcon(_ severity: AlertSeverity) -> String {
        switch severity {
        case .critical: return "🚨"
        case .high: return "⚠️"
        case .medium: return "⚡️"
        case .low: return "ℹ️"
        }
    }
}
```

### Test Mode Controls
```swift
struct TestModeView: View {
    @EnvironmentObject var healthService: HealthMonitoringService

    var body: some View {
        Form {
            Section("Test Mode") {
                Toggle("Enable Test Mode", isOn: Binding(
                    get: { healthService.isTestMode },
                    set: { enabled in
                        if enabled {
                            healthService.enableTestMode()
                        } else {
                            healthService.disableTestMode()
                        }
                    }
                ))
            }

            if healthService.isTestMode {
                Section("Trigger Test Scenarios") {
                    Button("High Heart Rate Alert") {
                        healthService.triggerTestHeartRateHigh()
                    }

                    Button("Low Heart Rate Alert") {
                        healthService.triggerTestHeartRateLow()
                    }

                    Button("Fall Detection Alert") {
                        healthService.triggerTestFall()
                    }
                }
            }
        }
        .navigationTitle("Testing")
    }
}
```

---

## 🐛 Troubleshooting

### No data appearing?
```swift
// Check connection:
print(healthService.isConnected)        // Should be true

// Check test mode:
print(healthService.isTestMode)         // Should be true if testing

// Check latest data:
print(healthService.currentHeartRate)   // Should not be nil
```

### Alerts not triggering?
```swift
// Check wear status (alerts only trigger when worn):
print(healthService.currentWearStatus)  // Should be .worn

// In test mode, wear status toggles every 10 seconds
```

### BLE not connecting?
```swift
// Check Bluetooth permissions in Settings > Privacy
// Check device name matches BLE scan filters
// Try stopping and restarting scan:
healthService.stopBLEScanning()
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    healthService.startBLEScanning()
}
```

---

## ✅ Complete Example App

```swift
import SwiftUI

@main
struct BEACONApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(HealthMonitoringService.shared)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var healthService: HealthMonitoringService
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.fill")
                }
                .tag(0)

            AlertsView()
                .tabItem {
                    Label("Alerts", systemImage: "bell.fill")
                }
                .tag(1)

            TestModeView()
                .tabItem {
                    Label("Test", systemImage: "testtube.2")
                }
                .tag(2)
        }
        .onAppear {
            // Optional: Auto-enable test mode for development
            #if DEBUG
            healthService.enableTestMode()
            #endif
        }
    }
}
```

---

## 🎉 You're Ready!

Your BEACON app is now fully self-contained and runs entirely on iOS!

**What you can do:**
- ✅ Develop without hardware (test mode)
- ✅ Connect to ESP32-C3 via BLE
- ✅ Monitor heart rate in real-time
- ✅ Detect falls automatically
- ✅ Receive smart alerts
- ✅ Track health history
- ✅ Works 100% offline

**No computer. No external server. Just iPhone + ESP32!** 📱💙

---

For detailed migration steps, see `MIGRATION_GUIDE.md`
