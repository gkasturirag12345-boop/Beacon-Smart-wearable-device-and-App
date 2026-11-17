# BEACON iOS Migration Guide
## From Computer Backend to Self-Contained iOS App

This guide will help you migrate from the computer-based backend to a fully self-contained iOS architecture.

---

## 📋 What's New

### New Files (Already Created):
1. **`AlertManager.swift`** - Smart alert system with wear detection
2. **`DataStore.swift`** - In-memory data storage with circular buffers
3. **`TestSimulator.swift`** - Test mode simulator for development
4. **`HealthMonitoringService.swift`** - Main coordinator that connects everything

### Files to Remove:
1. **`HTTPServerManager.swift`** ❌ (No longer needed!)
2. **`DeviceAPIService+Server.swift`** ❌ (HTTP simulation not needed)
3. **Vapor dependency** ❌ (Remove from Package.swift or project)

### Files to Keep (No changes needed):
- ✅ `BLEManager.swift` - Works exactly the same
- ✅ `NotificationService.swift` - Works exactly the same
- ✅ `HealthData.swift` - Your data models
- ✅ All View files - Minimal changes needed

---

## 🚀 Step-by-Step Migration

### Step 1: Add New Files to Xcode Project

1. Open your `BEACON_2.xcodeproj` in Xcode
2. Right-click on the `Services` folder
3. Select "Add Files to BEACON..."
4. Add these 4 new files:
   - `AlertManager.swift`
   - `DataStore.swift`
   - `TestSimulator.swift`
   - `HealthMonitoringService.swift`

5. Make sure "Copy items if needed" is checked
6. Click "Add"

### Step 2: Update ContentView.swift

**Replace this:**
```swift
@StateObject private var apiService = DeviceAPIService()
```

**With this:**
```swift
@StateObject private var healthService = HealthMonitoringService.shared
```

**Update your views:**
```swift
var body: some View {
    TabView(selection: $selectedTab) {
        DashboardView()
            .environmentObject(healthService)  // Changed!
            .tabItem {
                Label("Dashboard", systemImage: "house.fill")
            }
        // ... rest of your tabs
    }
}
```

### Step 3: Update DashboardView.swift

**Replace this:**
```swift
@EnvironmentObject var apiService: DeviceAPIService
```

**With this:**
```swift
@EnvironmentObject var healthService: HealthMonitoringService
```

**Update data fetching:**

**OLD:**
```swift
currentHeartRate = try await apiService.fetchCurrentHeartRate()
```

**NEW:**
```swift
currentHeartRate = healthService.getCurrentHeartRate()
```

### Step 4: Update ServerTestView.swift

Rename to `TestModeView.swift` and update:

**OLD:**
```swift
@EnvironmentObject var deviceAPI: DeviceAPIService
```

**NEW:**
```swift
@EnvironmentObject var healthService: HealthMonitoringService
```

**Update controls:**

**OLD:**
```swift
if deviceAPI.isConnected {
    deviceAPI.stopHTTPServer()
} else {
    await deviceAPI.startHTTPServer(port: 8080)
}
```

**NEW:**
```swift
if healthService.isTestMode {
    healthService.disableTestMode()
} else {
    healthService.enableTestMode()
}
```

**OLD:**
```swift
await deviceAPI.simulateHeartRate(bpm: bpm)
```

**NEW:**
```swift
TestSimulator.shared.triggerHighHeartRate()  // For high HR test
// or
TestSimulator.shared.triggerLowHeartRate()   // For low HR test
```

### Step 5: Update BLEConnectionView.swift

**OLD:**
```swift
BLEConnectionView(bleManager: apiService.getBLEManager())
```

**NEW:**
```swift
BLEConnectionView(bleManager: healthService.bleManager)
```

Or even simpler:
```swift
BLEConnectionView()
    .environmentObject(healthService)
```

Then inside BLEConnectionView:
```swift
@EnvironmentObject var healthService: HealthMonitoringService

// Access BLE functions through healthService
Button("Scan") {
    healthService.startBLEScanning()
}

// Show discovered devices
List(healthService.getDiscoveredDevices(), id: \.identifier) { peripheral in
    Button(peripheral.name ?? "Unknown") {
        healthService.connect(to: peripheral)
    }
}
```

### Step 6: Remove Old Files

1. **Delete from Xcode:**
   - Right-click `HTTPServerManager.swift` → Delete → Move to Trash
   - Right-click `DeviceAPIService+Server.swift` → Delete → Move to Trash

2. **Remove Vapor Dependency:**
   - Open your project settings
   - Go to "Package Dependencies"
   - Find "Vapor" and click the minus button to remove
   - Or if using CocoaPods/SPM, edit your dependency file

3. **Keep but update:**
   - Keep `DeviceAPIService.swift` but update it (see Step 7)

### Step 7: Simplify DeviceAPIService.swift (Optional)

You can keep DeviceAPIService as a compatibility layer, or replace it entirely with HealthMonitoringService.

**Option A: Compatibility Wrapper**
```swift
class DeviceAPIService: ObservableObject {
    private let healthService = HealthMonitoringService.shared

    var isConnected: Bool {
        return healthService.isConnected
    }

    func fetchCurrentHeartRate() async throws -> HeartRateData {
        guard let hr = healthService.getCurrentHeartRate() else {
            throw APIError.noData
        }
        return hr
    }

    // ... other wrapper methods
}
```

**Option B: Direct Replacement (Recommended)**
Just use `HealthMonitoringService` everywhere and delete `DeviceAPIService`.

---

## 🧪 Testing Your Migration

### Test 1: Test Mode
```swift
// In your app:
healthService.enableTestMode()

// Should see:
// - Connection status: "Test Mode Active"
// - Heart rate updating every 2 seconds
// - Wear status toggling every 10 seconds
```

### Test 2: BLE Connection
```swift
// In your app:
healthService.startBLEScanning()

// Should see:
// - Discovered devices appear
// - Can connect to ESP32
// - Heart rate data flows from device
```

### Test 3: Alerts
```swift
// Trigger test alert:
healthService.triggerTestHeartRateHigh()

// Should see:
// - Alert appears in activeAlerts
// - iOS notification sent
// - Alert logged in history
```

---

## 📊 New Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│                  iOS APP                        │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │      HealthMonitoringService             │  │
│  │         (Main Coordinator)               │  │
│  └────────┬─────────┬─────────┬─────────────┘  │
│           │         │         │                 │
│     ┌─────▼──┐  ┌──▼─────┐ ┌─▼─────────┐      │
│     │ BLE    │  │ Alert  │ │ Data      │      │
│     │Manager │  │Manager │ │ Store     │      │
│     └─────┬──┘  └────────┘ └───────────┘      │
│           │                                     │
│           │    ┌──────────────┐                │
│           │    │ Test         │                │
│           │    │ Simulator    │                │
│           │    └──────────────┘                │
│           │                                     │
│     ┌─────▼────────┐                           │
│     │ Notification │                           │
│     │ Service      │                           │
│     └──────────────┘                           │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │             SwiftUI Views                │  │
│  │  (Dashboard, HeartRate, Fall, etc.)      │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
           │
           │ BLE
           ▼
    ┌──────────────┐
    │   ESP32-C3   │
    │   Device     │
    └──────────────┘
```

**Everything runs on the iPhone!** ✅

---

## 🎯 What You Get

### Before (Computer Backend):
- ❌ Need to run `npm start` on computer
- ❌ iPhone must be on same WiFi
- ❌ Complex HTTP/WebSocket setup
- ❌ Can't use app away from computer
- ❌ Vapor dependency issues

### After (iOS-Only):
- ✅ Runs 100% on iPhone
- ✅ No computer needed
- ✅ Works anywhere (even offline)
- ✅ Simpler architecture
- ✅ Faster performance
- ✅ No external dependencies

---

## 🐛 Troubleshooting

### "Cannot find HealthMonitoringService in scope"
**Solution:** Make sure you added the 4 new Swift files to your Xcode project.

### "Cannot find type 'AlertType'"
**Solution:** AlertType is defined in `AlertManager.swift`. Add that file first.

### "Cannot find type 'WearStatus'"
**Solution:** WearStatus is defined in `AlertManager.swift`.

### Vapor still causing issues
**Solution:**
1. Remove Vapor from Package Dependencies
2. Clean build folder (Cmd+Shift+K)
3. Delete DerivedData
4. Rebuild project

### Test mode not working
**Solution:**
```swift
// Make sure to call this:
healthService.enableTestMode()

// Check status:
print(healthService.isTestMode)  // Should be true
```

---

## 💡 Usage Examples

### Enable Test Mode
```swift
Button("Enable Test Mode") {
    healthService.enableTestMode()
}
.disabled(healthService.isConnected && !healthService.isTestMode)
```

### Connect to BLE Device
```swift
Button("Scan for Devices") {
    healthService.startBLEScanning()
}

List(healthService.getDiscoveredDevices(), id: \.identifier) { device in
    Button(device.name ?? "Unknown") {
        healthService.connect(to: device)
    }
}
```

### Display Current Heart Rate
```swift
Text("Heart Rate: \(healthService.currentHeartRate ?? 0, specifier: "%.0f") BPM")
    .font(.system(size: 48, weight: .bold))
```

### Show Active Alerts
```swift
List(healthService.activeAlerts.filter { !$0.resolved }) { alert in
    VStack(alignment: .leading) {
        Text(alert.message)
            .font(.headline)
        Text(alert.timestamp, style: .relative)
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
```

### Trigger Test Scenarios
```swift
Button("Test High Heart Rate") {
    healthService.triggerTestHeartRateHigh()
}

Button("Test Fall Detection") {
    healthService.triggerTestFall()
}
```

---

## ✅ Migration Checklist

- [ ] Add 4 new Swift files to Xcode project
- [ ] Update ContentView to use HealthMonitoringService
- [ ] Update DashboardView data fetching
- [ ] Update BLEConnectionView to use new service
- [ ] Rename/update ServerTestView to TestModeView
- [ ] Remove HTTPServerManager.swift
- [ ] Remove DeviceAPIService+Server.swift
- [ ] Remove Vapor dependency
- [ ] Test: Enable test mode
- [ ] Test: Connect to BLE device
- [ ] Test: Receive heart rate data
- [ ] Test: Trigger alerts
- [ ] Build and run successfully!

---

## 🎉 You're Done!

Your BEACON app now runs 100% on iOS with no computer backend needed!

**Next steps:**
1. Test thoroughly with test mode
2. Connect to your ESP32-C3 device
3. Verify alerts work correctly
4. Deploy to TestFlight or App Store

**Need help?** Check the code comments in each new file for detailed explanations.
