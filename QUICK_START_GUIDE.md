# BEACON BLE Bandwidth Fix - Quick Start Guide

## ⚡ Quick Summary

Your BEACON device now uses **ADPCM compression** (4:1 ratio) and **priority-based scheduling** to fix BLE bandwidth saturation.

**Bandwidth**: 256 kbps → **32-64 kbps** (75-87% reduction)

---

## 📦 Files Added

### ESP32-C3 Firmware:
- ✅ `ADPCMCodec.h` / `ADPCMCodec.cpp` - Audio compression encoder
- ✅ `DataScheduler.h` / `DataScheduler.cpp` - Priority-based BLE transmission

### iOS App:
- ✅ `ADPCMDecoder.swift` - Audio decompression decoder

---

## 🔧 Files Modified

### ESP32-C3:
- ✅ `Config.h` - Added compression & BLE optimization parameters
- ✅ `AudioDetector.h` / `.cpp` - ADPCM compression + VAD
- ✅ `BLEManager.h` / `.cpp` - DataScheduler + connection optimization
- ✅ `HeartRateSensor.cpp` - 1 Hz update throttling
- ✅ `Code_that_works2.ino` - Integrated DataScheduler

### iOS:
- ✅ `BLEManager.swift` - MTU negotiation (247 bytes)
- ✅ `KeywordSpotterTFLite.swift` - ADPCM decompression

---

## 🚀 How to Deploy

### Step 1: Upload ESP32-C3 Firmware

```bash
# Open Arduino IDE
# Load: Code_that_works2.ino
# Select Board: ESP32-C3 Dev Module
# Upload
```

### Step 2: Update iOS App

1. Add `ADPCMDecoder.swift` to Xcode project
2. Build and run on iPhone
3. Connect to "ESP32-BEACON" device

---

## ✅ Verification

### ESP32 Serial Monitor Should Show:

```
[DataScheduler] Initializing priority queues...
[DataScheduler] Queue sizes - Critical: 10, High: 10, Normal: 20
[Audio] ADPCM compression enabled (4:1 ratio)
[Audio] Adaptive sample rate enabled (8-16 kHz)
[BLE] Connection parameter update requested:
  - Interval: 15ms (optimized for throughput)
  - Supervision timeout: 5000ms (prevent disconnects)
```

### iOS App Should Log:

```
[BLE] Successfully connected to ESP32-BEACON
[BLE] 🔧 Connection optimization: Requesting max MTU (247 bytes)
[BLE] 🔧 Expecting ADPCM-compressed audio from ESP32 (4:1 ratio)
[BLE] Negotiated MTU: 247 bytes
[BLE] 🎤 Subscribed to audio stream from ESP32 microphone (16kHz, 16-bit)
```

---

## 📊 Key Parameters

| Parameter | Value | Purpose |
|-----------|-------|---------|
| **Audio compression** | ADPCM 4:1 | Reduce bandwidth 256→64 kbps |
| **VAD threshold** | 1500 RMS | Detect voice activity |
| **Audio rate (high)** | 30 pkt/s | Voice detected |
| **Audio rate (low)** | 15 pkt/s | Background noise |
| **Heart rate update** | 1 Hz | Throttle from per-beat |
| **BLE interval** | 15ms | Faster than default 30ms |
| **BLE timeout** | 5000ms | Prevent disconnects |
| **MTU** | 247 bytes | Maximum packet size |

---

## 🐛 Troubleshooting

### No audio streaming?
- Check: `audioDetector.enableStreaming(true)` in setup()
- Check: DataScheduler initialized before AudioDetector

### Heart rate not updating?
- Check: `HR_UPDATE_INTERVAL = 1000` in Config.h
- Check: BLE connection active

### Connection still timing out?
- Check: MTU negotiation logged in iOS
- Check: BLE connection parameters updated
- Try: Move closer to device (signal strength)

---

## 🎯 Expected Performance

- ✅ **Audio bandwidth**: 32-64 kbps (adaptive)
- ✅ **Heart rate delivery**: 1 Hz, 100% reliable
- ✅ **Alert latency**: <100ms
- ✅ **Connection stability**: No timeouts
- ✅ **Total BLE usage**: ~40-70 kbps (well within 100-125 kbps capacity)

---

## 📝 Quick Reference: Priority System

```
CRITICAL (Priority 0) - Immediate transmission
├─ FALL_DETECTED
├─ HEART_STOP
├─ MANUAL_ALERT
├─ FALSE_ALARM
└─ DEVICE_WORN / DEVICE_NOT_WORN

HIGH (Priority 1) - Guaranteed 1 Hz
└─ Heart Rate (every 1 second)

NORMAL (Priority 2) - Best effort, rate-limited
└─ Audio (ADPCM-compressed, 15-30 pkt/s adaptive)
```

---

## 🔍 Monitoring Tips

### ESP32 Serial Monitor:
- Watch for: `[Audio] Voice activity detected - increasing rate to 30 pkt/s`
- Watch for: `[Audio] Voice inactive - reducing rate to 15 pkt/s`
- Watch for: `[DataScheduler] WARNING:` messages (queue full)

### iOS Console:
- Watch for: `[BLE RX] 🎤 Audio data received: X bytes`
- Watch for: `[KeywordSpotter] SOS detected with confidence: X`
- Watch for: Heart rate updates every 1 second

---

## 💡 Pro Tips

1. **Test VAD**: Speak loudly near device, observe rate increase in serial monitor
2. **Test priorities**: Press button while audio streaming, verify alert immediate
3. **Monitor queues**: Check DataScheduler queue counts in serial (every 30s)
4. **Check MTU**: iOS should log "Negotiated MTU: 247 bytes" on connect

---

## 📞 Support

For issues or questions, refer to:
- `BLE_BANDWIDTH_FIX_SUMMARY.md` - Detailed technical documentation
- `BLE_CONNECTION_FIX.md` - BLE troubleshooting guide (existing)
- Serial monitor output for real-time diagnostics

---

**Status**: ✅ Implementation Complete

All code changes have been implemented and are ready for testing.
