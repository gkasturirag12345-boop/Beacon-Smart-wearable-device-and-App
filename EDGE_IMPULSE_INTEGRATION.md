# Edge Impulse C++ SDK Integration Guide

## Overview

This document describes how the BEACON iOS app integrates the Edge Impulse C++ SDK for SOS voice detection.

## Architecture

```
Swift App (KeywordSpotterEI.swift)
        ↓
Objective-C++ Bridge (EdgeImpulseBridge.mm)
        ↓
Edge Impulse C++ SDK (run_classifier)
        ↓
TensorFlow Lite Model (sos_model.tflite)
```

## Files Created

### 1. Bridge Files

- **BEACON-Bridging-Header.h**: Exposes Objective-C++ classes to Swift
- **EdgeImpulseBridge.h**: Objective-C interface definition
- **EdgeImpulseBridge.mm**: Objective-C++ implementation that calls Edge Impulse C++ SDK
- **KeywordSpotterEI.swift**: Swift wrapper for audio recording + inference

### 2. Edge Impulse SDK

Located in: `BEACON/sos_voice_recognition-cpp-mcu-vers3_tinyconv2dmodel/`

Contains:
- `edge-impulse-sdk/`: C++ SDK headers and implementation
- `model-parameters/`: Model configuration and variables
- `tflite-model/`: Compiled TensorFlow Lite model

## Xcode Build Settings

### Required Settings

Add these to your Xcode project:

#### 1. Header Search Paths

```
$(PROJECT_DIR)/BEACON/sos_voice_recognition-cpp-mcu-vers3_tinyconv2dmodel
$(PROJECT_DIR)/BEACON/sos_voice_recognition-cpp-mcu-vers3_tinyconv2dmodel/edge-impulse-sdk
$(PROJECT_DIR)/BEACON/sos_voice_recognition-cpp-mcu-vers3_tinyconv2dmodel/model-parameters
$(PROJECT_DIR)/BEACON/sos_voice_recognition-cpp-mcu-vers3_tinyconv2dmodel/tflite-model
```

**How to add**:
1. Select BEACON target → Build Settings
2. Search for "Header Search Paths"
3. Add the paths above (mark as "recursive" if needed)

#### 2. Objective-C Bridging Header

```
$(SRCROOT)/BEACON/BEACON-Bridging-Header.h
```

**How to add**:
1. Select BEACON target → Build Settings
2. Search for "Objective-C Bridging Header"
3. Set the path above

#### 3. C++ Language Standard

```
CLANG_CXX_LANGUAGE_STANDARD = gnu++17
```

**How to add**:
1. Select BEACON target → Build Settings
2. Search for "C++ Language Dialect"
3. Set to "GNU++17"

#### 4. Enable Objective-C ARC

```
CLANG_ENABLE_OBJC_ARC = YES
```

This should already be enabled, but verify:
1. Select BEACON target → Build Settings
2. Search for "Objective-C Automatic Reference Counting"
3. Ensure it's set to "Yes"

#### 5. Compile Sources

Ensure `EdgeImpulseBridge.mm` is added to "Compile Sources":
1. Select BEACON target → Build Phases
2. Expand "Compile Sources"
3. Verify `EdgeImpulseBridge.mm` is listed
4. If not, click "+" and add it

### Compiler Flags (if needed)

If you encounter warnings, add these to EdgeImpulseBridge.mm only:

1. Select BEACON target → Build Phases → Compile Sources
2. Double-click `EdgeImpulseBridge.mm`
3. Add flags: `-Wno-deprecated-declarations -Wno-unused-variable`

## How It Works

### 1. Initialization

```swift
// KeywordSpotterEI.swift
eiWrapper = EdgeImpulseWrapper()  // Calls run_classifier_init()
```

### 2. Audio Capture

- Records audio at 16kHz mono using AVAudioEngine
- Maintains rolling 1-second buffer (16,000 samples)
- Resamples from hardware rate (48kHz) to model rate (16kHz)

### 3. Inference

```swift
let result = eiWrapper.runInference(audioBuffer, length: 16000)
```

Internally, `EdgeImpulseBridge.mm` does:
```cpp
// Create signal from audio buffer
numpy::signal_from_buffer(audioBuffer, length, &signal);

// Run classifier (includes DSP + ML inference)
run_classifier(&signal, &ei_result, false);
```

### 4. Result Processing

```swift
if let classifications = result.classifications {
    let sosConfidence = classifications["SOS"]?.floatValue ?? 0.0
    // Trigger alert if sosConfidence > threshold
}
```

## Edge Impulse DSP Pipeline

The `run_classifier()` function automatically performs:

1. **Framing**: Split 1s audio into overlapping 20ms frames
2. **FFT**: 256-point FFT on each frame
3. **Mel Filterbank**: 40 mel-scale filters
4. **Log Compression**: log10 with noise floor normalization (-90dB)
5. **Quantization**: Convert to int8
6. **ML Inference**: Run TFLite model
7. **Dequantization**: Convert output back to float32

**Total output**: 3960 features (99 frames × 40 filters)

## Model Information

- **Project**: SOS_Voice_Recognition
- **Project ID**: 800799
- **Classes**: ["SOS", "noises", "unknown"]
- **Input**: 16,000 samples @ 16kHz (1 second)
- **Sample Rate**: 16,000 Hz
- **Detection Threshold**: 0.3 (configurable)

## Usage in App

### Replace Old Implementation

Update `HealthMonitoringService.swift`:

```swift
// OLD:
// private let keywordSpotter = KeywordSpotter()

// NEW:
private let keywordSpotter = KeywordSpotterEI()
```

### Monitor Detections

```swift
keywordSpotter.$latestDetection
    .receive(on: DispatchQueue.main)
    .sink { detection in
        if let detection = detection, detection.isDetected {
            // Trigger SOS alert
            alertManager.triggerSOSVoiceAlert(confidence: detection.confidence)
        }
    }
    .store(in: &cancellables)
```

## Troubleshooting

### Linker Errors

If you see "Undefined symbols for architecture arm64":
- Check Header Search Paths are correctly configured
- Verify EdgeImpulseBridge.mm is in "Compile Sources"
- Clean build folder (⌘ + Shift + K)

### Runtime Crashes

If app crashes on inference:
- Check audio buffer length is exactly 16,000 samples
- Verify `run_classifier_init()` was called before inference
- Check console for Edge Impulse error messages

### No Detections

If SOS is never detected:
- Lower threshold in KeywordDetection.swift
- Check Xcode console for confidence values
- Verify microphone permission is granted
- Test with clear "SOS" pronunciation

## Performance

- **Inference Time**: ~50-100ms on iPhone (includes DSP + ML)
- **CPU Usage**: ~5-10% continuous
- **Memory**: ~50MB for model + buffers

## Future Improvements

1. Add continuous audio streaming mode
2. Implement wake word detection before SOS
3. Add speaker verification
4. Support multiple languages
