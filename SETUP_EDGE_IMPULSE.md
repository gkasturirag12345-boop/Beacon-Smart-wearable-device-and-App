# Edge Impulse C++ SDK Setup Instructions

## ⚠️ IMPORTANT: Manual Xcode Configuration Required

Before building, you **MUST** configure these Xcode settings:

## Step 1: Configure Build Settings

### 1.1 Add Header Search Paths

1. Open `BEACON_5.xcworkspace` in Xcode
2. Select the `BEACON` target (blue icon at top of file navigator)
3. Click `Build Settings` tab
4. Search for `Header Search Paths`
5. Click the `+` button and add these paths:

```
$(PROJECT_DIR)/BEACON/sos_voice_recognition-cpp-mcu-vers3_tinyconv2dmodel
$(PROJECT_DIR)/BEACON/sos_voice_recognition-cpp-mcu-vers3_tinyconv2dmodel/edge-impulse-sdk
$(PROJECT_DIR)/BEACON/sos_voice_recognition-cpp-mcu-vers3_tinyconv2dmodel/model-parameters
$(PROJECT_DIR)/BEACON/sos_voice_recognition-cpp-mcu-vers3_tinyconv2dmodel/tflite-model
```

Make sure all paths are set to `recursive`.

### 1.2 Set Objective-C Bridging Header

1. In `Build Settings`, search for `Objective-C Bridging Header`
2. Set the value to:

```
$(SRCROOT)/BEACON/BEACON-Bridging-Header.h
```

### 1.3 Set C++ Language Standard

1. In `Build Settings`, search for `C++ Language Dialect`
2. Set to `GNU++17` (or `c++17`)

### 1.4 Verify Objective-C ARC

1. In `Build Settings`, search for `Objective-C Automatic Reference Counting`
2. Ensure it's set to `Yes`

## Step 2: Add Source Files to Build

### 2.1 Add EdgeImpulseBridge.mm

1. Select the `BEACON` target
2. Click `Build Phases` tab
3. Expand `Compile Sources`
4. Click the `+` button
5. Find and add `Services/EdgeImpulseBridge.mm`

### 2.2 Verify Other Files

Make sure these files are also in `Compile Sources`:
- `KeywordSpotterEI.swift` (NEW - replaces KeywordSpotterTFLite)
- `KeywordDetection.swift`
- `HealthMonitoringService.swift`

## Step 3: Update HealthMonitoringService

Replace the old KeywordSpotter with the new Edge Impulse version:

```swift
// OLD:
// private let keywordSpotter = KeywordSpotter()

// NEW:
private let keywordSpotter = KeywordSpotterEI()
```

## Step 4: Clean and Build

1. Clean build folder: `⌘ + Shift + K`
2. Build: `⌘ + B`
3. If successful, install on device

## Expected Build Errors (and Fixes)

### Error: "Use of undeclared identifier 'run_classifier'"

**Fix**: Header Search Paths not configured correctly. Go back to Step 1.1.

### Error: "Use of undeclared identifier 'EdgeImpulseWrapper'"

**Fix**: Bridging header not configured. Go back to Step 1.2.

### Error: "No such module 'TensorFlowLite'"

**Fix**: Edge Impulse SDK includes its own TFLite. Remove TensorFlowLite pod dependency if it exists.

### Error: "'EdgeImpulseBridge.mm' does not appear in target"

**Fix**: Add EdgeImpulseBridge.mm to Compile Sources (Step 2.1).

## Verify Installation

After successful build, check Xcode console for:

```
[EdgeImpulse] ✅ Classifier initialized
[EdgeImpulse] Model: SOS_Voice_Recognition
[EdgeImpulse] Expected input: 16000 samples @ 16000 Hz
[KeywordSpotterEI] ✅ Edge Impulse classifier loaded successfully
[KeywordSpotterEI] ✅ Audio engine started - listening for SOS...
```

## Testing

1. Say "SOS" clearly into the iPhone microphone
2. Check Xcode console for inference results:

```
========================================
[KeywordSpotterEI] 🎯 Inference Result
========================================
  Predicted: SOS
  Confidences:
    • Noise:   0.050
    • SOS:     0.920 ⭐️
    • Unknown: 0.030
  Threshold: 0.3
  Is Detected: ✅ YES
  Inference Time: 85.2ms
========================================
[KeywordSpotterEI] 🚨 SOS DETECTED! Triggering alert...
```

## Troubleshooting

### No audio input

- Check microphone permissions: Settings → BEACON → Microphone
- Verify AVAudioEngine is running

### Inference fails

- Check buffer size is exactly 16,000 samples
- Verify Edge Impulse classifier initialized successfully
- Look for error messages in console

### Low confidence for SOS

- Speak clearly and pronounce "S-O-S" as separate letters
- Increase volume
- Lower detection threshold (currently 0.3)

## Files Created

These files were automatically created:

1. `BEACON/BEACON-Bridging-Header.h`
2. `BEACON/Services/EdgeImpulseBridge.h`
3. `BEACON/Services/EdgeImpulseBridge.mm`
4. `BEACON/Services/KeywordSpotterEI.swift`
5. `EDGE_IMPULSE_INTEGRATION.md` (detailed documentation)

## Next Steps

After successful integration:

1. Remove old files (optional):
   - `AudioPreprocessor.swift` (no longer needed)
   - `KeywordSpotterTFLite.swift` (replaced by KeywordSpotterEI)

2. Test SOS detection thoroughly
3. Adjust detection threshold if needed
4. Deploy to device and test in real scenarios

## Support

See `EDGE_IMPULSE_INTEGRATION.md` for detailed technical documentation.

---

**Created**: November 3, 2025
**Edge Impulse SDK Version**: 1.75
**Model**: SOS_Voice_Recognition (Project ID: 800799)
