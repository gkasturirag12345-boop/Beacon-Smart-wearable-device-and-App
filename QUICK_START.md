# Quick Start Guide - BEACON6 iOS App

## ✅ Build Status: SUCCESS

The app is ready to run! Follow these steps to test the SOS keyword detection.

---

## Run the App

### Option 1: iOS Simulator (Recommended for Testing)

```bash
cd ~/Documents/BEACON_Project/BEACON6_iOS

# Open project in Xcode
open BEACON6.xcodeproj

# In Xcode:
# 1. Select an iPhone simulator (e.g., "iPhone 16 Pro")
# 2. Press Cmd+R or Product > Run
```

### Option 2: Physical iPhone

```bash
# Same as above, but:
# 1. Connect your iPhone via USB
# 2. Select your iPhone from the device menu
# 3. Press Cmd+R or Product > Run
# 4. Trust the app on your phone when prompted
```

### Option 3: Command Line Build

```bash
cd ~/Documents/BEACON_Project/BEACON6_iOS

# Build for Simulator
xcodebuild -project BEACON6.xcodeproj \
           -scheme BEACON \
           -sdk iphonesimulator \
           -configuration Debug build

# Build for Device
xcodebuild -project BEACON6.xcodeproj \
           -scheme BEACON \
           -sdk iphoneos \
           -configuration Debug build
```

---

## Test SOS Detection

### 1. Launch and Check Console

After running the app, check Xcode console (Cmd+Shift+Y) for:

```
✅ Expected Output:
[HealthMonitoringService] Initialized
[HealthMonitoringService] 🎤 Initializing SOS voice detection...
[KeywordSpotter] 🔄 Initializing CoreML Sound Classifier...
[KeywordSpotter] ✅ CoreML Sound Classifier loaded
[KeywordSpotter]    Model: SOSKeywordClassifier
[KeywordSpotter]    Classes: sos, oh_ess, noise, unknown
[HealthMonitoringService] ✅ ML model loaded - starting SOS detection...
[KeywordSpotter] 🎤 Started listening for SOS keyword...
```

### 2. Test SOS Detection

**Say "SOS" clearly into the microphone**

```
✅ Expected Response:
[KeywordSpotter] 🔊 sos: 0.954 | SOS: 0.954
[KeywordSpotter] 🚨 SOS DETECTED! Confidence: 0.915
[HealthMonitoringService] 🚨 SOS KEYWORD DETECTED - Triggering alert
```

**Alert should appear in app UI**

### 3. Test False Positive Rejection

**Say "oh ess" (should NOT trigger)**

```
✅ Expected Response:
[KeywordSpotter] 🔊 oh_ess: 0.892 | SOS: 0.108
(No alert triggered)
```

---

## App Features to Test

### 1. BLE Connection (if you have ESP32 hardware)
- Navigate to BLE tab
- Start scanning
- Connect to "BEACON" device
- Verify: `[HealthMonitoringService] 🎤 External audio enabled (ESP32 mic)`

### 2. Test Mode (no hardware needed)
- Enable Test Mode in app settings
- Trigger simulated events:
  - High heart rate alert
  - Low heart rate alert
  - Fall detection
- Verify alerts appear

### 3. Alert History
- Navigate to Alerts tab
- View triggered SOS alerts
- Resolve/delete alerts
- Check alert statistics

### 4. Dashboard
- View real-time heart rate (if connected to ESP32 or in test mode)
- Monitor connection status
- Check wear status
- View active alerts

---

## Microphone Permission

If SOS detection doesn't work, check microphone permission:

```
iOS Settings > Privacy & Security > Microphone > BEACON
```

Make sure it's **enabled**.

---

## Adjusting Detection Sensitivity

If you get too many false positives or miss real SOS utterances:

### Edit `BEACON6/Services/KeywordSpotter.swift`

```swift
// Line ~35: Lower threshold = more sensitive (more false positives)
private let detectionThreshold: Float = 0.8  // Try 0.7-0.9

// Line ~38: More history = smoother but slower
private let historySize: Int = 3  // Try 2-5

// Line ~41: Longer interval = fewer rapid-fire alerts
private let minDetectionInterval: TimeInterval = 2.0  // Try 1.0-3.0
```

After editing, rebuild: `Product > Build` (Cmd+B)

---

## Common Issues

### Issue: "Model not found in bundle"

**Solution:**
```bash
# Verify model exists
ls -l BEACON6/Resources/SOSKeywordClassifier.mlmodel

# Clean and rebuild
# In Xcode: Product > Clean Build Folder (Cmd+Shift+K)
# Then: Product > Build (Cmd+B)
```

### Issue: "No audio input detected"

**Solution:**
1. Check microphone permission (Settings > Privacy > Microphone)
2. Check that another app isn't using the microphone
3. Restart the app
4. On simulator, check System Preferences > Security & Privacy > Privacy > Microphone

### Issue: "Build failed with provisioning error"

**Solution:**
```bash
# Use simulator instead of device
# In Xcode, select an iPhone Simulator from device menu
# Then rebuild
```

### Issue: "SOS always detected" (too sensitive)

**Solution:**
```swift
// In KeywordSpotter.swift, increase threshold:
private let detectionThreshold: Float = 0.9  // Was 0.8
```

### Issue: "SOS never detected" (not sensitive enough)

**Solution:**
```swift
// In KeywordSpotter.swift, decrease threshold:
private let detectionThreshold: Float = 0.7  // Was 0.8

// Or reduce smoothing:
private let historySize: Int = 2  // Was 3
```

---

## Performance Testing

### Test Different Environments

1. **Quiet room:** Should detect SOS reliably
2. **Background conversation:** Test rejection of non-SOS speech
3. **Music playing:** Test noise rejection
4. **Different volumes:** Test sensitivity range
5. **Different speakers:** Test voice variation handling

### Measure Performance

Enable detailed logging in `KeywordSpotter.swift`:

```swift
// Uncomment line ~115 for all classifications:
print("[KeywordSpotter] 🔊 \(topClass): \(topConf) | SOS: \(sosConfidence)")
```

This shows confidence scores for all audio windows.

---

## App Architecture

```
BEACON6
├── Views/
│   ├── DashboardView.swift         (Main dashboard)
│   ├── BLEConnectionView.swift     (ESP32 connection)
│   ├── KeywordSpottingView.swift   (SOS detection UI)
│   └── AlertsView.swift            (Alert history)
├── Services/
│   ├── HealthMonitoringService.swift  (Main coordinator)
│   ├── KeywordSpotter.swift           (SOS detection - NEW CoreML!)
│   ├── BLEManager.swift               (Bluetooth handling)
│   ├── AlertManager.swift             (Alert processing)
│   ├── DataStore.swift                (Data persistence)
│   └── ADPCMDecoder.swift             (ESP32 audio decoding)
├── Models/
│   └── [Data models]
└── Resources/
    └── SOSKeywordClassifier.mlmodel   (CoreML model - NEW!)
```

---

## What Changed from TensorFlow Lite

### Before (Old Implementation)
```
Audio → Manual MFE → TensorFlow Lite → Detection
- Requires: CocoaPods (TensorFlowLiteSwift)
- Requires: Objective-C++ bridges
- Requires: Manual feature extraction
- Large model, slow inference
```

### After (New Implementation)
```
Audio → SoundAnalysis → CoreML → Detection
- Zero dependencies
- Pure Swift
- Automatic preprocessing
- Small model (13KB), fast inference
```

**Benefits:**
- ✅ Simpler codebase (~40% smaller)
- ✅ Faster inference (Neural Engine optimized)
- ✅ Better iOS integration
- ✅ No external dependencies
- ✅ Easier to maintain

---

## Next Steps After Testing

1. ✅ **Test on simulator** - Verify SOS detection works
2. ✅ **Test on device** - Test with real-world audio
3. ✅ **Test with ESP32** - Verify BLE audio integration
4. ✅ **Measure accuracy** - Record false positive/negative rates
5. ⏭️ **Tune parameters** - Adjust thresholds if needed
6. ⏭️ **Retrain model** - If accuracy needs improvement
7. ⏭️ **Deploy to TestFlight** - Beta testing

---

## Resources

- **Full migration docs:** `COREML_MIGRATION_COMPLETE.md`
- **Build success details:** `BUILD_SUCCESS.md`
- **Xcode setup guide:** `XCODE_MODEL_SETUP_INSTRUCTIONS.md`
- **Model training script:** `~/Documents/BEACON_Project/train_sos_classifier.swift`
- **Dataset location:** `~/Documents/BEACON_Project/CreateML_SOS_Dataset/`

---

## Support

If you encounter issues not covered here:

1. Check build logs in Xcode (View > Navigators > Report Navigator)
2. Check console logs during runtime (Cmd+Shift+Y)
3. Review the migration documentation
4. Verify all files are in correct locations:
   ```bash
   # Model should exist:
   ls -l BEACON6/Resources/SOSKeywordClassifier.mlmodel

   # No old files should exist:
   ls BEACON6/Resources/sos_model.tflite  # Should error: No such file
   ls Podfile  # Should error: No such file
   ```

---

**Status:** ✅ Ready to test
**Build:** ✅ Success
**Model:** ✅ Loaded (93.33% validation accuracy)

**Enjoy testing the new CoreML-powered SOS detection!** 🎉
