# BLE Connection Fix for ESP32-C3 BEACON

## Problem
ESP32-C3 device not appearing in iOS app when scanning for Bluetooth devices.

## Root Cause Analysis
The optimized firmware changed the BLE device name from a simple name to "ESP32-C3-HealthMonitor", which may have caused discoverability issues. Additionally, advertising settings were not optimized for iOS devices.

## Changes Made

### 1. **Device Name Simplified**
```cpp
// OLD
NimBLEDevice::init("ESP32-C3-HealthMonitor");

// NEW
NimBLEDevice::init("ESP32-BEACON");
```
- Simpler name is easier for iOS to discover
- Still contains "ESP32" for iOS app filtering
- More consistent with app branding

### 2. **Increased BLE Power Level**
```cpp
// NEW - Maximum transmission power for better range
NimBLEDevice::setPower(ESP_PWR_LVL_P9);
```
- Increases Bluetooth range significantly
- Helps iPhone discover device from further away
- Essential for stable connections

### 3. **Improved Advertising Configuration**
```cpp
// NEW - Better iOS compatibility
pAdvertising->setScanResponse(true);
pAdvertising->setMinPreferred(0x06);
pAdvertising->setMaxPreferred(0x12);
```
- `setScanResponse(true)` - Sends scan response packets for better discoverability
- Connection interval parameters help with iPhone connection stability

### 4. **Enhanced Debug Output**
- Device name printed on startup
- Service UUID displayed
- Advertising status shown every 30 seconds
- Connection/disconnection events logged clearly

## How to Flash Updated Firmware

### Method 1: Arduino IDE
```
1. Open beacon5/beacon5.ino in Arduino IDE
2. Select board: "ESP32C3 Dev Module"
3. Connect ESP32-C3 via USB
4. Click Upload button
5. Wait for "Done uploading"
```

### Method 2: Command Line (arduino-cli)
```bash
cd /Users/kasturirajguhan/Documents/BEACON_Project/beacon5

# IMPORTANT: Use min_spiffs partition (firmware won't fit in default partition)
arduino-cli compile --fqbn esp32:esp32:esp32c3:PartitionScheme=min_spiffs beacon5.ino
arduino-cli upload -p /dev/cu.usbserial-* --fqbn esp32:esp32:esp32c3:PartitionScheme=min_spiffs beacon5.ino
```

## Testing Steps

### 1. Flash and Monitor Serial Output
```
1. Flash the updated firmware
2. Open Serial Monitor (115200 baud)
3. Press ESP32-C3 reset button
4. Look for these lines:
   =================================
   NimBLE initialized
   Device name: ESP32-BEACON
   Service UUID: 12345678-9012-3456-7890-1234567890AB
   Advertising: ACTIVE
   =================================
```

### 2. Test iOS App Discovery
```
1. Open BEACON app on iPhone
2. Go to "Bluetooth" tab
3. Tap "Scan for Devices"
4. Watch Serial Monitor - should see:
   [BLE] Status: Waiting for connection...
   [BLE] Device name: ESP32-BEACON
   [BLE] Advertising: YES
5. Device should appear as "ESP32-BEACON" in app
```

### 3. Test Connection
```
1. Tap on "ESP32-BEACON" in device list
2. Serial Monitor should show:
   [BLE] Client connected successfully
3. App should show "Connected" status
4. Heart rate data should start flowing
```

## Troubleshooting

### Device Still Not Appearing?

**Check 1: Bluetooth is On**
- Settings → Bluetooth → Ensure ON
- iOS Control Center → Long press Bluetooth → Should be blue

**Check 2: App Permissions**
- Settings → Privacy & Security → Bluetooth → BEACON → Allow

**Check 3: Serial Monitor Output**
```
Open Serial Monitor and verify:
✓ "Advertising: ACTIVE" appears
✓ No error messages
✓ Status prints every 30 seconds showing "Advertising: YES"
```

**Check 4: Reset ESP32-C3**
```
1. Unplug USB cable
2. Wait 5 seconds
3. Plug back in
4. Press physical reset button
5. Wait for "Advertising: ACTIVE" message
```

**Check 5: Restart iPhone App**
```
1. Force quit BEACON app (swipe up)
2. Relaunch app
3. Go to Bluetooth tab
4. Try scanning again
```

**Check 6: Restart iPhone Bluetooth**
```
1. Control Center → Bluetooth OFF
2. Wait 3 seconds
3. Control Center → Bluetooth ON
4. Open BEACON app and scan
```

### Connection Drops Immediately?

**Solution 1: Check Power**
```
- Use USB cable directly to computer (not hub)
- Ensure ESP32-C3 has stable 5V power
- Battery voltage should be > 3.7V
```

**Solution 2: Reduce Distance**
```
- Keep iPhone within 2 meters of ESP32-C3
- Remove obstacles between devices
- Avoid WiFi routers or microwaves nearby
```

**Solution 3: Check Serial Monitor**
```
If you see:
"[BLE] WARNING: Advertising stopped unexpectedly"
→ This is normal, firmware automatically restarts it
```

### Still Having Issues?

**Full Reset Procedure:**
```
1. ESP32-C3:
   - Hold BOOT button
   - Press RESET button
   - Release BOOT button
   - Flash firmware again

2. iPhone:
   - Settings → Bluetooth
   - Tap (i) next to ESP32-BEACON
   - Tap "Forget This Device"
   - Restart iPhone
   - Open BEACON app and scan fresh

3. Check iOS app logs:
   - Open Xcode
   - Window → Devices and Simulators
   - Select your iPhone
   - Click "Open Console"
   - Filter for "BLE"
   - Look for discovery messages
```

## Expected Behavior After Fix

✅ **Device appears in scan within 2-3 seconds**
✅ **Shows as "ESP32-BEACON" in device list**
✅ **Connection establishes in < 5 seconds**
✅ **Heart rate data starts streaming immediately**
✅ **Serial Monitor shows "Client connected successfully"**
✅ **App status shows "Connected"**

## Key Improvements

1. **Simpler Device Name**: "ESP32-BEACON" (was "ESP32-C3-HealthMonitor")
2. **Maximum BLE Power**: ESP_PWR_LVL_P9 for extended range
3. **Scan Response Enabled**: Better iPhone discoverability
4. **Connection Intervals Optimized**: Stable iPhone connections
5. **Enhanced Debugging**: Clear status messages every 30 seconds
6. **Auto-Recovery**: Advertising automatically restarts if stopped

## Technical Details

**Device Name**: ESP32-BEACON
**Service UUID**: 12345678-9012-3456-7890-1234567890AB
**BLE Stack**: NimBLE (optimized for ESP32-C3)
**Advertising Interval**: Default (configurable if needed)
**TX Power**: +9 dBm (maximum)
**Connection Parameters**: Optimized for iOS

## Files Modified

- `beacon5/BLEManager.cpp` (lines 64-118, 120-160)
  - Changed device name
  - Added power level configuration
  - Enhanced advertising setup
  - Improved debug logging

## Verification Checklist

Before considering the issue fixed, verify:

- [ ] ESP32-C3 shows "Advertising: ACTIVE" on boot
- [ ] Serial Monitor shows device name "ESP32-BEACON"
- [ ] iOS app discovers device within 3 seconds
- [ ] Device appears with correct name in list
- [ ] Connection establishes successfully
- [ ] Heart rate data streams to app
- [ ] Connection remains stable for 60+ seconds
- [ ] Disconnect/reconnect works properly

---

**Last Updated**: October 21, 2025
**Firmware Version**: Beacon 5 - NimBLE Optimized
**iOS App Version**: BEACON 1.0 (build 1)
