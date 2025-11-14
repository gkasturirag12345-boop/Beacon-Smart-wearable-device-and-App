# ESP32-C3 BEACON - Modular Health Monitor Firmware

## 🚀 Quick Start

### 1. Install NimBLE Library
```
Arduino IDE → Tools → Manage Libraries...
Search: "NimBLE-Arduino"
Install: "NimBLE-Arduino by h2zero" (v1.4.0+)
```

### 2. Configure Partition Scheme
```
Arduino IDE → Tools → Partition Scheme
Select: "Huge APP (3MB No OTA/1MB SPIFFS)"
```

### 3. Compile and Upload
```
Open: beacon5.ino
Click: Verify (✓)
Expected: ~80% flash usage (~1,150KB / 1,441KB)
```

## 📁 Project Structure

```
beacon5/
├── beacon5.ino              ← Main file (open this in Arduino IDE)
├── Config.h                 ← All constants and thresholds
├── BLEManager.cpp/h         ← NimBLE communication
├── HeartRateSensor.cpp/h    ← MAX30105 sensor
├── FallDetector.cpp/h       ← BNO085 IMU
├── PowerManager.cpp/h       ← Sleep modes
├── ButtonController.cpp/h   ← Button debouncing
├── wifi_manager.h           ← WiFi provisioning
├── web_server.h             ← HTTP REST API
├── network_manager.h        ← Network coordination
└── legacy_backup/           ← Old monolithic version
    ├── beacon5.ino          (original 1,114 lines)
    └── OPTIMIZATION_GUIDE.md
```

## 🎯 Optimizations Applied

- ✅ **NimBLE** instead of full BLE stack (-80KB)
- ✅ **Modular architecture** (-85KB from better optimization)
- ✅ **Huge APP partition** (+130KB available flash)
- ✅ **PROGMEM strings** (F() macro for all Serial output)

**Result**: ~80% flash usage with ~290KB headroom for I²S microphone

## 🔧 Hardware Requirements

- ESP32-C3 CodeCell
- MAX30105 heart rate sensor (I2C)
- BNO085 9-DOF IMU (I2C)
- VCNL4040 proximity sensor (I2C)
- Button on GPIO 7

## 📡 Features

- ✅ Heart rate monitoring with beat detection
- ✅ IR-based wear detection
- ✅ Fall detection (2.5g spike + stationary)
- ✅ BLE communication (NimBLE)
- ✅ WiFi provisioning via BLE
- ✅ HTTP REST API on port 8080
- ✅ Power management (light/deep sleep)
- ✅ Button alerts (single/double press)

## 🐛 Troubleshooting

**Error: `NimBLEDevice.h: No such file`**
→ Install NimBLE-Arduino library (see Quick Start #1)

**Error: Flash overflow (>100%)**
→ Change partition scheme to "Huge APP" (see Quick Start #2)

**Error: `undefined reference to 'ClassName::method()'`**
→ Ensure all .cpp files are in same folder as .ino

**Runtime: BLE not advertising**
→ Check Serial monitor for "NimBLE initialized - advertising started"

## 📊 Expected Build Output

```
Sketch uses 1,150,000 bytes (79%) of program storage space. Maximum is 1,441,792 bytes.
Global variables use 45,000 bytes (13%) of dynamic memory.
```

## 📞 Support

Check `legacy_backup/OPTIMIZATION_GUIDE.md` for detailed optimization documentation.

---

**Version**: 2.0 (Modular + NimBLE)
**Last Updated**: 2025-10-20
**Target Board**: ESP32-C3 CodeCell
