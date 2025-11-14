# SOS Detection Troubleshooting - Zero Confidence Issue

## 🚨 Problem Identified

Your console logs show the model is **NOT detecting SOS** - confidence is stuck at 0.000:

```
[KeywordSpotter] 🔊 noise: 0.744 | SOS: 0.000 | 2nd: unknown(0.256) | Δ: -0.256
[KeywordSpotter] 🔊 noise: 1.000 | SOS: 0.000 | 2nd: unknown(0.000) | Δ: -0.000
[KeywordSpotter] 🔊 unknown: 0.998 | SOS: 0.000 | 2nd: noise(0.001) | Δ: -0.001
```

But ONE successful detection proves the model CAN work:
```
[KeywordSpotter] 🔊 sos: 0.969 | SOS: 0.969 | 2nd: oh_ess(0.025) | Δ: 0.944 ✅
```

## 🔍 Root Cause Analysis

### Why is SOS confidence 0.000?

The model is classifying everything as `noise` or `unknown` because:

1. **Microphone is picking up ambient noise** (most likely)
2. **Audio is too quiet** - speaking too far from mic
3. **Audio format mismatch** - model expects different sample rate
4. **Model is overtrained on noise class** - needs retraining
5. **Voice Activity Detection needed** - analyzing silence/background noise

---

## ✅ Immediate Diagnostics (5 minutes)

I've added enhanced logging. Rebuild and run the app, then check console for:

### 1. Audio Quality Logs

**New log every 10 buffers:**
```
[KeywordSpotter] 🎤 Audio: RMS=0.000123, Peak=0.005432, Voice=NO
```

**What to look for:**
- **RMS < 0.001**: Audio is too quiet or silence
- **Peak < 0.01**: No significant sound detected
- **Voice=NO**: No speech activity detected

**Good audio should show:**
```
[KeywordSpotter] 🎤 Audio: RMS=0.024567, Peak=0.345678, Voice=YES ✅
```

### 2. All Classes Confidence (every 20 inferences)

```
[KeywordSpotter] 📊 All classes: sos=0.000 oh_ess=0.003 noise=0.997 unknown=0.000
```

**What to look for:**
- If `noise` or `unknown` is always >0.9, you're recording silence/ambient noise
- If `sos` is NEVER >0.1, even when you speak, there's a problem

### 3. Warning Messages (every 100 inferences if SOS < 0.01)

```
[KeywordSpotter] ⚠️ WARNING: SOS confidence has been near-zero for 100 inferences
[KeywordSpotter] 💡 This suggests:
[KeywordSpotter]    1. Microphone picking up only ambient noise
[KeywordSpotter]    2. Audio format mismatch with model
[KeywordSpotter]    3. Model needs retraining with better SOS samples
```

---

## 🛠️ Fix Attempt 1: Check Microphone Quality

### Test 1: Verify Microphone is Working

```bash
# Open Xcode, run app, start SOS detection
# Watch console for audio quality logs
```

**Expected when you say "SOS" loudly and clearly:**
```
[KeywordSpotter] 🎤 Audio: RMS=0.025000, Peak=0.450000, Voice=YES
[KeywordSpotter] 🔊 sos: 0.892 | SOS: 0.892 | 2nd: noise(0.098) | Δ: 0.794
```

**If you see this instead:**
```
[KeywordSpotter] 🎤 Audio: RMS=0.000234, Peak=0.012000, Voice=NO
[KeywordSpotter] 🔊 noise: 0.998 | SOS: 0.000 | ...
```

**Then**: Microphone is not picking up your voice properly.

**Solutions:**
1. **Speak closer to the phone** (10-20cm / 4-8 inches)
2. **Speak louder** (normal conversation volume minimum)
3. **Check microphone permissions** (Settings → BEACON → Microphone → Enabled)
4. **Test with other apps** (Voice Memos) to verify mic works
5. **Remove phone case** if blocking microphone
6. **Clean microphone port** if dusty/dirty

---

## 🛠️ Fix Attempt 2: Audio Session Configuration

Check if audio session is configured correctly.

### Verify in KeywordSpotter.swift:162-164

```swift
let audioSession = AVAudioSession.sharedInstance()
try audioSession.setCategory(.record, mode: .measurement, options: [])
try audioSession.setActive(true)
```

**Try changing mode:**

```swift
// Option 1: Voice chat mode (optimized for speech)
try audioSession.setCategory(.record, mode: .voiceChat, options: [])

// Option 2: Spoken audio mode
try audioSession.setCategory(.record, mode: .spokenAudio, options: [])
```

**Rebuild and test** - voice modes may improve speech detection.

---

## 🛠️ Fix Attempt 3: Adjust Voice Activity Detection Thresholds

The VAD may be too strict, rejecting valid speech.

### Edit KeywordSpotter.swift:324-325

```swift
// Current (may be too strict)
let minEnergy: Float = 0.001  // RMS energy threshold
let minPeak: Float = 0.01     // Peak amplitude threshold

// Try more lenient (accept quieter speech)
let minEnergy: Float = 0.0005  // Lower threshold
let minPeak: Float = 0.005     // Lower threshold
```

This will allow quieter speech through to the model.

---

## 🛠️ Fix Attempt 4: Disable VAD Temporarily (Debug Mode)

To isolate if VAD is the problem:

### Edit KeywordSpotter.swift:214-223

```swift
// TEMPORARY: Comment out VAD to test if it's the issue
// Only analyze if we have actual audio (not silence)
// if hasVoice {
    self.streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
// } else {
//     // Log silence detection less frequently
//     if self.totalInferences % 50 == 0 {
//         NSLog("[KeywordSpotter] 🔇 Skipping inference - silence/low audio detected")
//     }
// }
```

**Rebuild and test** - if SOS detection works now, VAD thresholds are too strict.

**Re-enable VAD** after testing with proper thresholds.

---

## 🛠️ Fix Attempt 5: Model Input Format Verification

Verify the model is receiving audio in the correct format.

### Check Audio Format (KeywordSpotter.swift:176-177)

```swift
let inputFormat = inputNode.outputFormat(forBus: 0)
streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)
```

**Add logging to verify format:**

```swift
let inputFormat = inputNode.outputFormat(forBus: 0)
NSLog("[KeywordSpotter] 🎚️ Input format: %@ Hz, %d channels, %@",
      String(describing: inputFormat.sampleRate),
      inputFormat.channelCount,
      inputFormat.commonFormat == .pcmFormatFloat32 ? "Float32" : "Other")

streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)
```

**Expected output:**
```
[KeywordSpotter] 🎚️ Input format: 48000.0 Hz, 1 channels, Float32
```

**Model expects:** 22,050 Hz (SoundAnalysis will resample automatically)

**If format is wrong:**
- Sample rate should be >16kHz (44.1kHz or 48kHz is fine)
- Channels must be 1 (mono)
- Format should be Float32

---

## 🛠️ Fix Attempt 6: Test with Known Good Audio File

Bypass microphone entirely and test with a pre-recorded "SOS" audio file.

### Create Test Method

Add to KeywordSpotter.swift:

```swift
func testWithAudioFile(filePath: String) throws {
    let fileURL = URL(fileURLWithPath: filePath)
    let audioFile = try AVAudioFile(forReading: fileURL)

    guard let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: audioFile.fileFormat.sampleRate,
        channels: 1,
        interleaved: false
    ) else { return }

    let frameCount = AVAudioFrameCount(audioFile.length)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

    try audioFile.read(into: buffer)

    print("[KeywordSpotter] 🧪 Testing with file: \(filePath)")
    streamAnalyzer?.analyze(buffer, atAudioFramePosition: 0)

    // Wait for result
    Thread.sleep(forTimeInterval: 0.5)
}
```

**Usage:**

1. Record yourself saying "SOS" in Voice Memos
2. Export as WAV file
3. Add to Xcode project
4. Call: `keywordSpotter.testWithAudioFile(filePath: "/path/to/sos.wav")`

**Expected result:**
```
[KeywordSpotter] 🧪 Testing with file: sos.wav
[KeywordSpotter] 🔊 sos: 0.945 | SOS: 0.945 | 2nd: noise(0.045) | Δ: 0.900 ✅
```

**If this works but live mic doesn't:**
→ Microphone input quality is the problem

**If this ALSO shows SOS: 0.000:**
→ Model needs retraining (see below)

---

## 🔥 Fix Attempt 7: Retrain Model (Most Effective)

Based on your logs, the model appears to be **overtrained on the `noise` and `unknown` classes**.

### Evidence:
- `noise` confidence: 0.744, 1.000, 0.999, 0.993, 0.980 (very high)
- `unknown` confidence: 0.998, 0.994, 0.656 (very high)
- `sos` confidence: 0.000 (almost always zero)

**This means**: During training, the model learned to classify most audio as noise/unknown.

### Solution: Retrain with Better Dataset

Follow the guide: `SOS_DATA_COLLECTION_GUIDE.md`

**Quick steps:**

1. **Collect more SOS samples** (need 500+ more)
   ```bash
   # Use Audacity or Voice Memos
   # Record yourself saying "SOS" 100 times
   # In various conditions: quiet, noisy, different volumes
   ```

2. **Balance dataset** - reduce noise/unknown samples
   ```bash
   # Current imbalance:
   # unknown: 1,026 samples (38.8%)
   # sos: 683 samples (25.8%)
   # noise: 418 samples (15.8%)

   # Target balance:
   # sos: 1,200 samples (30%)
   # unknown: 1,000 samples (25%)
   # noise: 800 samples (20%)
   # oh_ess: 1,000 samples (25%)
   ```

3. **Reorganize dataset**
   ```bash
   cd ~/Documents/BEACON_Project
   swift reorganize_dataset.swift
   ```

4. **Retrain model**
   ```bash
   swift train_sos_classifier.swift
   ```

5. **Test new model**
   ```bash
   swift test_model_performance.swift \
       SOSKeywordClassifier.mlmodel \
       ~/Downloads/CreateML_SOS_Dataset/Testing
   ```

**Expected result after retraining:**
- SOS confidence should be >0.7 when you say "SOS"
- Noise/unknown should be <0.2 when you say "SOS"
- Overall accuracy: 93% → 98%+

---

## 📊 Diagnostic Checklist

Work through this checklist to identify the issue:

- [ ] **Audio Quality Check**
  - [ ] Speak loudly and clearly into phone
  - [ ] Check console for: `RMS > 0.01, Peak > 0.1, Voice=YES`
  - [ ] If NO: Microphone is not picking up voice

- [ ] **Microphone Permissions**
  - [ ] Settings → BEACON → Microphone → Enabled
  - [ ] First launch shows permission dialog
  - [ ] Console shows: `Microphone permission: GRANTED`

- [ ] **Audio Session Mode**
  - [ ] Try `.voiceChat` mode instead of `.measurement`
  - [ ] Test if SOS confidence increases

- [ ] **VAD Thresholds**
  - [ ] Lower thresholds to 0.0005 (RMS) and 0.005 (Peak)
  - [ ] Or temporarily disable VAD
  - [ ] Check if SOS confidence appears

- [ ] **Test with Audio File**
  - [ ] Create test WAV file of "SOS"
  - [ ] Test with `testWithAudioFile()`
  - [ ] If works: Mic issue. If not: Model issue.

- [ ] **Model Retraining** (if above fails)
  - [ ] Collect 500+ new SOS samples
  - [ ] Balance dataset classes
  - [ ] Retrain with Create ML
  - [ ] Deploy new model

---

## 🎯 Most Likely Cause (Based on Your Logs)

**90% chance**: Microphone is picking up ambient noise, not your voice.

**Evidence:**
- Most classifications are `noise: 0.9+` or `unknown: 0.9+`
- SOS is consistently `0.000` (model never sees SOS audio features)
- ONE successful detection (0.969) when audio was good

**Quick Test:**
1. Hold phone 10cm from mouth
2. Say "SOS" very loudly and clearly
3. Watch console for `RMS` value
   - If RMS < 0.01 → You're too quiet or far away
   - If RMS > 0.02 → Audio is good, model should detect

**If RMS is good but SOS still 0.000:**
→ Model retraining required (dataset issue)

---

## 🚀 Immediate Action Plan

### Today (30 minutes)
1. ✅ Rebuild app with new diagnostics
2. 🔍 Check console for audio quality logs
3. 🎤 Test with loud, clear "SOS" at 10cm distance
4. 📝 Note the RMS/Peak values when speaking

### If RMS is low (<0.01)
→ **Microphone issue**
- Speak louder/closer
- Change audio session mode to `.voiceChat`
- Lower VAD thresholds
- Check microphone permissions

### If RMS is good (>0.02) but SOS still 0.000
→ **Model issue**
- Collect 100 new SOS recordings
- Retrain model
- Expected: 1-2 hours work

---

## 📞 Next Steps

**After fixing:**

1. Verify SOS detection with 20 test utterances
2. Measure false positive rate (say random words)
3. Test in noisy environment (TV on, traffic sounds)
4. Deploy if >95% detection rate achieved

**Need help?**
- Check enhanced console logs for diagnostic messages
- Review `SOS_DATA_COLLECTION_GUIDE.md` for retraining
- Run `test_model_performance.swift` to measure current accuracy

---

**Status**: 🔧 Diagnostics enhanced - Rebuild app and check console logs
**Most Likely Fix**: Speak louder/closer OR retrain model with more SOS samples
