# ✅ BEACON System Verification Guide

**Use this guide to verify your complete BEACON system setup.**

---

## 📋 Pre-Flight Checklist

### Required Hardware
- [ ] iPhone (iOS 15.0+)
- [ ] ESP32-C3 CodeCell development board
- [ ] MAX30105 heart rate sensor (I2C)
- [ ] BNO085 9-DOF IMU (I2C)
- [ ] VCNL4040 proximity sensor (I2C)
- [ ] I2S MEMS microphone
- [ ] Push button (GPIO 3)
- [ ] USB cable for programming
- [ ] Breadboard & jumper wires (for testing)

### Required Software
- [ ] macOS with Xcode 16.0+
- [ ] Arduino IDE or arduino-cli
- [ ] ESP32 board support installed
- [ ] NimBLE-Arduino library installed

---

## 🔍 Step-by-Step Verification

### Phase 1: ESP32-C3 Firmware Upload ⚡

#### 1.1 Install NimBLE Library
```bash
# Option 1: Arduino IDE
Arduino IDE → Tools → Manage Libraries
Search: "NimBLE-Arduino"
Install: "NimBLE-Arduino by h2zero" (v1.4.0+)

# Option 2: arduino-cli
arduino-cli lib install "NimBLE-Arduino"
```

**✅ Success:** Library appears in Library Manager

---

#### 1.2 Configure Partition Scheme
```bash
Arduino IDE → Tools → Partition Scheme
Select: "Huge APP (3MB No OTA/1MB SPIFFS)"
```

**✅ Success:** Partition scheme shows in Tools menu

---

#### 1.3 Upload Firmware
```bash
cd ~/Documents/BEACON_Project/finalised_code/Code_that_works2

# Method 1: Arduino IDE
# Open Code_that_works2.ino
# Tools → Board → ESP32 Arduino → ESP32C3 Dev Module
# Tools → Port → Select /dev/cu.usbserial-*
# Click Upload (→)

# Method 2: arduino-cli
arduino-cli compile --fqbn esp32:esp32:esp32c3 Code_that_works2
arduino-cli upload -p /dev/cu.usbserial-* --fqbn esp32:esp32:esp32c3 Code_that_works2
```

**✅ Success Indicators:**
```
Sketch uses 1,150,000 bytes (79%) of program storage space.
Global variables use 45,000 bytes (13%) of dynamic memory.
Upload complete
```

**Serial Monitor Output:**
```
[ESP32] System initialized
[BLE] NimBLE initialized - advertising started
[HeartRate] MAX30105 initialized
[IMU] BNO085 initialized
[Proximity] VCNL4040 initialized
[Audio] I2S microphone initialized
```

**❌ Common Issues:**
- **NimBLE not found** → Install NimBLE-Arduino library (Step 1.1)
- **Flash overflow** → Change partition to "Huge APP" (Step 1.2)
- **Port not found** → Check USB cable, try different port
- **Upload fails** → Hold BOOT button during upload

---

### Phase 2: Hardware Verification 🔌

#### 2.1 I2C Sensor Check
```bash
# Open Serial Monitor (115200 baud)
arduino-cli monitor -p /dev/cu.usbserial-* -c baudrate=115200
```

**Expected Output:**
```
[I2C] Scanning I2C bus...
[I2C] Found device at 0x4A (BNO085 IMU)
[I2C] Found device at 0x57 (MAX30105 HR Sensor)
[I2C] Found device at 0x60 (VCNL4040 Proximity)
[I2C] All sensors detected ✓
```

**✅ Success:** All 3 sensors found
**❌ Failure:**
- Check I2C wiring (SDA=GPIO8, SCL=GPIO9)
- Verify 3.3V power supply
- Check pull-up resistors on SDA/SCL (4.7kΩ)

---

#### 2.2 Heart Rate Sensor Test
**Place finger on MAX30105 sensor**

**Expected Serial Output:**
```
[HeartRate] IR value: 45000 (finger detected)
[HeartRate] Beat detected! BPM: 72
[HeartRate] SpO2: 98%
[HeartRate] Sending HR to BLE: 72 BPM
```

**✅ Success:** Heart rate 40-200 BPM, stable readings
**❌ Failure:**
- **HR = 0 or no beat** → Improve finger placement, check sensor power
- **Erratic readings** → Clean sensor surface, press firmly
- **IR value < 10000** → No finger detected, increase pressure

---

#### 2.3 Fall Detection Test
**Shake ESP32-C3 device vigorously**

**Expected Serial Output:**
```
[IMU] Linear accel: X=1.2 Y=0.8 Z=3.4 (magnitude: 3.8 G)
[FallDetector] FALL THRESHOLD EXCEEDED! 3.8G >= 2.5G
[BLE] Sending fall alert to iOS app
```

**✅ Success:** Fall detected when magnitude ≥ 2.5G
**❌ Failure:**
- **No detection** → Check BNO085 IMU wiring, increase shake intensity
- **Always detecting** → Lower threshold in Config.h

---

#### 2.4 Proximity Sensor (Wear Detection) Test
**Move hand over VCNL4040 sensor**

**Expected Serial Output:**
```
[Proximity] Distance: 50mm (not worn)
[Proximity] Distance: 5mm (worn - sensor covered)
[BLE] Wear status: WORN
```

**✅ Success:** Distance changes when hand approaches
**❌ Failure:**
- **Distance always 0** → Check VCNL4040 power/I2C
- **No response** → Verify I2C address (0x60)

---

#### 2.5 Audio Detection Test (Optional)
**Make loud noise near I2S microphone**

**Expected Serial Output:**
```
[Audio] Amplitude: 8500 (threshold: 5000)
[Audio] Thud detected!
[BLE] Sending audio alert
```

**✅ Success:** Audio events detected on loud sounds
**❌ Failure:**
- **No audio** → Check I2S wiring (BCLK=GPIO5, WS=GPIO6, SD=GPIO7)
- **Always silent** → Verify microphone power (3.3V)

---

#### 2.6 Button Test
**Press button on GPIO 3**

**Expected Serial Output:**
```
[Button] Single press detected
[BLE] Manual SOS alert triggered
```

**Double-press button:**
```
[Button] Double press detected
[BLE] False alarm - canceling alert
```

**✅ Success:** Button presses detected with debouncing
**❌ Failure:**
- **No response** → Check button wiring, verify pull-up enabled
- **Multiple triggers** → Increase debounce delay

---

### Phase 3: iOS App Build & Run 📱

#### 3.1 Build iOS App
```bash
cd ~/Documents/BEACON_Project/finalised_code/BEACON6_iOS

# Open in Xcode
open BEACON6.xcodeproj

# OR build from command line
xcodebuild -project BEACON6.xcodeproj \
           -scheme BEACON \
           -sdk iphonesimulator \
           -configuration Debug build
```

**✅ Success:**
```
** BUILD SUCCEEDED **
```

**❌ Common Issues:**
- **Missing model** → Verify `BEACON6/Resources/SOSKeywordClassifier.mlmodel` exists
- **Provisioning error** → Use simulator instead of device
- **Build errors** → Clean: Product → Clean Build Folder (Cmd+Shift+K)

---

#### 3.2 Grant Permissions
After launching app:

1. **Microphone Permission**
   - Prompt: "BEACON needs microphone access..."
   - Action: Tap "Allow"
   - Verify: Settings → Privacy → Microphone → BEACON ✅

2. **Bluetooth Permission**
   - Should auto-grant (iOS 13+)
   - Verify: Settings → Privacy → Bluetooth → BEACON ✅

3. **Location Permission**
   - Prompt: "BEACON needs location access..."
   - Action: Tap "Allow While Using App"
   - Verify: Settings → Privacy → Location → BEACON ✅

4. **Notification Permission**
   - Prompt: "BEACON wants to send notifications"
   - Action: Tap "Allow"
   - Verify: Settings → Notifications → BEACON ✅

---

### Phase 4: System Integration Testing 🔗

#### 4.1 BLE Connection Test
**In iOS App:**
1. Navigate to "Bluetooth" tab
2. Tap "Scan for Devices"
3. Wait 5-10 seconds

**✅ Expected:**
```
Devices Found:
  • BEACON (ESP32-C3)
    Signal: -45 dBm
    Status: Available
```

4. Tap "BEACON" device
5. Wait for connection

**✅ Expected:**
```
Status: Connected ✅
Connection Mode: BLE
```

**Console Output (iOS):**
```
[BLEManager] Connecting to BEACON...
[BLEManager] ✅ Connected successfully
[BLEManager] Discovered custom NimBLE service
[BLEManager] Subscribed to Heart Rate characteristic
```

**Console Output (ESP32 Serial Monitor):**
```
[BLE] Client connected!
[BLE] Heart rate characteristic subscribed
```

**❌ Troubleshooting:**
- **Device not found** → Check ESP32 powered, restart ESP32
- **Connection fails** → Reset Bluetooth on iPhone
- **No service** → Verify NimBLE advertising on ESP32

---

#### 4.2 Heart Rate Streaming Test
**After BLE connection, place finger on MAX30105**

**iOS App Dashboard:**
```
Heart Rate: 75 BPM ❤️
Status: Normal
Last Update: Just now
```

**Expected Behavior:**
- Heart rate updates every ~1 second
- Values in range 40-200 BPM
- Green indicator for normal, yellow/red for abnormal

**iOS Console Output:**
```
[BLEManager] ❤️ Heart Rate: 75 BPM
[HealthMonitoringService] Heart rate updated: 75 BPM
```

**ESP32 Serial Monitor:**
```
[HeartRate] Beat detected! BPM: 75
[BLE] Sending HR: 75 to iOS app
[DataScheduler] High priority data sent
```

**✅ Success:** Real-time heart rate displayed on iOS
**❌ Failure:** Values stuck at 0 → Check MAX30105 sensor, finger placement

---

#### 4.3 Fall Detection Test
**Shake ESP32-C3 device vigorously (>2.5G)**

**Expected iOS Alert:**
```
🚨 FALL DETECTED!
Magnitude: 3.2 G
Location: [Your Address]
Time: 20:42:15

[I'm OK]  [Need Help]
```

**iOS Console Output:**
```
[BLEManager] Received alert: FALL_DETECTED
[AlertManager] 🚨 Fall threshold met: 3.2 G >= 2.5 G
[AlertManager] ✅ Triggering fall alert
[NotificationService] Sending critical notification
```

**ESP32 Serial Monitor:**
```
[IMU] Linear accel magnitude: 3.2 G
[FallDetector] FALL THRESHOLD EXCEEDED!
[BLE] Sending FALL_DETECTED alert
```

**✅ Success:** Notification appears within 2 seconds of shake
**❌ Failure:**
- **No alert** → Check BNO085 wiring, increase shake intensity
- **Alert but no notification** → Check iOS notification permissions

---

#### 4.4 SOS Voice Detection Test (iOS Microphone)
**Say "SOS" clearly into iPhone microphone**

**Expected iOS Behavior:**
1. Audio visualizer shows sound wave
2. Confidence indicator rises
3. Alert banner appears:
```
⚠️ SOS DETECTED!
Confidence: 0.867
Time: 20:43:02

[Dismiss]  [Details]
```

**iOS Console Output:**
```
[KeywordSpotter] 🔊 sos: 0.867 | SOS: 0.867 | Δ: 0.737
[KeywordSpotter] ✅ SOS threshold met: 0.867 >= 0.600
[KeywordSpotter] ⚠️ SOS ALERT TRIGGERED at 20:43:02.145 | Confidence: 0.867 (HIGH)
[KeywordSpotter] ✅ Alert notification sent to AlertManager (conf: 0.867)
[HealthMonitoringService] 🚨 SOS KEYWORD DETECTED - Triggering alert
```

**✅ Success:** Alert within 500ms of saying "SOS"
**❌ Failure:**
- **No detection** → Check microphone permission, increase volume
- **False positives** → Adjust threshold in KeywordSpotter.swift line 39
- **Threshold not met** → Current: 0.6, try lowering to 0.5

---

#### 4.5 Audio Detection Test (ESP32 Microphone - Optional)
**Make loud noise near ESP32 I2S microphone**

**Expected ESP32 Serial Output:**
```
[Audio] Amplitude: 8500 (threshold: 5000)
[Audio] Thud detected!
[BLE] Sending audio alert to iOS
```

**Expected iOS Alert:**
```
⚠️ AUDIO ALERT
Loud sound detected
Time: 20:44:30
```

**✅ Success:** Audio events trigger iOS notification
**❌ Failure:**
- **No detection** → Check I2S microphone wiring
- **Always detecting** → Increase threshold in Config.h

---

#### 4.6 Manual Button Test
**Press button on ESP32-C3 (GPIO 3)**

**Expected ESP32 Serial Output:**
```
[Button] Single press detected
[BLE] Sending MANUAL_ALERT
```

**Expected iOS Alert:**
```
🚨 MANUAL SOS
Button pressed on device
Time: 20:45:00

[I'm OK]  [Need Help]
```

**✅ Success:** Button press triggers iOS notification
**❌ Failure:**
- **No response** → Check button wiring, verify GPIO 3
- **Multiple triggers** → Debounce issue, check ButtonController.cpp

---

## 📊 Final Verification Checklist

### Hardware ✅
- [ ] ESP32-C3 uploads and runs
- [ ] All I2C sensors detected (MAX30105, BNO085, VCNL4040)
- [ ] Heart rate sensor reads correctly (40-200 BPM)
- [ ] Fall detection triggers (≥2.5G)
- [ ] Proximity sensor detects wear status
- [ ] Audio detector works (optional)
- [ ] Button triggers alerts

### iOS App ✅
- [ ] Builds without errors
- [ ] All permissions granted (Mic, BLE, Location, Notifications)
- [ ] BLE connection established
- [ ] Heart rate streaming works
- [ ] Fall alerts trigger
- [ ] SOS voice detection works (iPhone mic)
- [ ] Location services work
- [ ] Notifications appear

### System Integration ✅
- [ ] Real-time heart rate on iOS
- [ ] Fall detection end-to-end (shake → iOS alert)
- [ ] Voice SOS triggers alert (iPhone mic → iOS alert)
- [ ] Audio detection works (ESP32 mic → iOS alert)
- [ ] Manual button works (GPIO 3 → iOS alert)
- [ ] Location in emergency alerts
- [ ] BLE transmission reliable

---

## 🎯 Performance Benchmarks

| Metric | Target | Your Result |
|--------|--------|-------------|
| **SOS Detection Latency** | <500ms | _______ ms |
| **Heart Rate Update** | ~1 Hz | _______ Hz |
| **Fall Alert Latency** | <2s | _______ s |
| **BLE Connection Time** | <5s | _______ s |
| **Voice Detection Accuracy** | >90% | _______ % |
| **ESP32 Flash Usage** | <90% | _______ % |
| **ESP32 RAM Usage** | <30% | _______ % |

---

## 🐛 Common Issues & Solutions

### Issue: NimBLE library not found
**Solution:**
```bash
Arduino IDE → Tools → Manage Libraries
Search: "NimBLE-Arduino"
Install: "NimBLE-Arduino by h2zero" (v1.4.0+)
```

### Issue: Flash overflow (>100%)
**Solution:**
```bash
Arduino IDE → Tools → Partition Scheme
Select: "Huge APP (3MB No OTA/1MB SPIFFS)"
```

### Issue: I2C sensors not detected
**Checklist:**
1. Verify I2C wiring (SDA=GPIO8, SCL=GPIO9)
2. Check 3.3V power supply
3. Add 4.7kΩ pull-up resistors on SDA/SCL
4. Run I2C scanner sketch to detect addresses

### Issue: SOS never triggers
**Cause:** Threshold too high
**Solution:** Edit `KeywordSpotter.swift` line 39:
```swift
private let detectionThreshold: Float = 0.5  // Was 0.6
```

### Issue: BLE device not found
**Checklist:**
1. ESP32-C3 powered on? Check USB/battery
2. NimBLE advertising? Check Serial Monitor for "advertising started"
3. Bluetooth enabled on iPhone?
4. Try restarting both devices

### Issue: Heart rate always 0
**Checklist:**
1. Finger on sensor correctly? Press firmly
2. MAX30105 I2C connected? Check address 0x57
3. IR value > 10000? Check Serial Monitor
4. Power supply sufficient? (3.3V, >100mA)

### Issue: Fall detection too sensitive
**Solution:** Edit `Config.h`:
```cpp
#define FALL_THRESHOLD 3.0  // Increase from 2.5
```

---

## ✅ System Status

After completing all tests, fill this out:

**Date:** _____________
**Tester:** _____________

**Overall System Status:**
- [ ] 🟢 All tests passed - Production ready
- [ ] 🟡 Minor issues - Functional with workarounds
- [ ] 🔴 Major issues - Requires fixes

**Notes:**
_________________________________
_________________________________
_________________________________

---

## 📄 Hardware Wiring Guide

### ESP32-C3 CodeCell Pin Connections

```
I2C Bus (shared by all sensors):
├─ SDA: GPIO 8
└─ SCL: GPIO 9

MAX30105 (Heart Rate):
├─ VCC → 3.3V
├─ GND → GND
├─ SDA → GPIO 8
└─ SCL → GPIO 9

BNO085 (IMU):
├─ VCC → 3.3V
├─ GND → GND
├─ SDA → GPIO 8
└─ SCL → GPIO 9

VCNL4040 (Proximity):
├─ VCC → 3.3V
├─ GND → GND
├─ SDA → GPIO 8
└─ SCL → GPIO 9

I2S Microphone:
├─ VCC → 3.3V
├─ GND → GND
├─ BCLK → GPIO 5
├─ WS → GPIO 6
└─ SD → GPIO 7

Push Button:
├─ One side → GPIO 3
└─ Other side → GND
   (Internal pull-up enabled)
```

---

**If all tests pass, your BEACON system is ready for deployment! 🎉**

For additional help, check:
- `README.md` - Main documentation
- `BEACON6_iOS/QUICK_START.md` - iOS app guide
- `Code_that_works2/README.md` - ESP32-C3 firmware guide
- `Code_that_works2/QUICK_START_GUIDE.md` - Hardware setup

**Support:** Check Serial Monitor and iOS console logs for detailed error messages
