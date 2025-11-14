# Fix Build Error & Add SOSKeywordClassifier to Xcode

## ✅ What's Been Fixed

1. **Removed duplicate model file** - Only one copy now exists at:
   ```
   BEACON6/Resources/SOSKeywordClassifier.mlmodel ✓
   ```

2. **Cleaned up Pods** - TensorFlowLite completely removed

3. **Cleaned derived data** - Removed old build artifacts

---

## 🚀 Next: Add Model to Xcode Project

### Step 1: Open Project in Xcode

```bash
cd ~/Documents/BEACON_Project/BEACON6_iOS
open BEACON6.xcworkspace
```

**IMPORTANT:** Open the `.xcworkspace` file, NOT the `.xcodeproj` file!

---

### Step 2: Add Model to Xcode

Since Xcode is using the **File System Synchronized Root Group** (new Xcode 15+ feature), the model should automatically be included. However, to ensure it's properly recognized:

#### Option A: Automatic (Xcode 15+)
The model is already in `BEACON6/Resources/` and should be auto-detected.

1. In Xcode, look at **Project Navigator** (left sidebar)
2. Expand `BEACON6 > Resources`
3. You should see `SOSKeywordClassifier.mlmodel`
4. Click on it to verify Xcode recognizes it as a Core ML model

#### Option B: Manual Add (if not showing)
If the model doesn't appear:

1. Right-click `BEACON6/Resources` folder in Project Navigator
2. Select **"Add Files to BEACON6..."**
3. Navigate to: `BEACON6/Resources/SOSKeywordClassifier.mlmodel`
4. **IMPORTANT Settings:**
   - ☑ **UNCHECK** "Copy items if needed" (file is already in place)
   - ☑ **CHECK** "BEACON" under "Add to targets"
   - Choose "Create groups" (not folder references)
5. Click **"Add"**

---

### Step 3: Verify Build Settings

Click on `SOSKeywordClassifier.mlmodel` in Project Navigator, then check the **File Inspector** (right sidebar):

**Target Membership:**
- ☑ BEACON

**Identity:**
- Type: "Core ML Model"
- Location: Should show as "Relative to Group"

---

### Step 4: Clean and Build

1. **Clean Build Folder:**
   - Menu: `Product > Clean Build Folder` (Cmd+Shift+K)

2. **Build Project:**
   - Menu: `Product > Build` (Cmd+B)

**Expected Result:** ✅ Build succeeds with no errors

---

## 🔍 Troubleshooting

### Error: "Multiple commands produce conflicting outputs"

**Solution:** The duplicate model file has been removed. If you still see this:

1. Select `BEACON6` target in Project Navigator
2. Go to **Build Phases** tab
3. Expand **"Compile Sources"**
4. Look for `SOSKeywordClassifier.mlmodel` appearing **twice**
5. If present, select the duplicate and click **"-"** to remove it
6. The model should only appear ONCE in **"Copy Bundle Resources"** (not in "Compile Sources")

### Error: "Model file not found in bundle"

**Solution:** Model is not being copied to app bundle.

1. Select `BEACON6` target → **Build Phases**
2. Expand **"Copy Bundle Resources"**
3. Click **"+"** and add `SOSKeywordClassifier.mlmodel`
4. Rebuild

### Build succeeds but app crashes with "Model not found"

**Check the model path in KeywordSpotter.swift:**

```swift
// Line 66-67 in KeywordSpotter.swift
guard let modelURL = Bundle.main.url(
    forResource: "SOSKeywordClassifier",
    withExtension: "mlmodelc"  // ← Xcode compiles .mlmodel to .mlmodelc
) ?? Bundle.main.url(
    forResource: "SOSKeywordClassifier",
    withExtension: "mlmodel"
) else {
    // Model not found
}
```

This code checks for both `.mlmodelc` (compiled) and `.mlmodel` (source), so it should work.

---

## ✅ Verification Checklist

After building successfully, verify the model is in the app:

### 1. Check Build Log
In Xcode build log, you should see:
```
CompileC ... SOSKeywordClassifier.mlmodelc
CopyPlistFile ... SOSKeywordClassifier.mlmodelc/metadata.plist
```

### 2. Check App Bundle
After building, the compiled model should be in the app bundle:

1. In Xcode, go to **Products** in Project Navigator
2. Right-click `BEACON.app` → **Show in Finder**
3. Right-click the `.app` → **Show Package Contents**
4. Navigate to `Contents/Resources/`
5. You should see `SOSKeywordClassifier.mlmodelc` (folder)

### 3. Test Runtime Loading
Run the app in Simulator/Device and check the console:

**Expected output:**
```
[KeywordSpotter] 🔄 Initializing CoreML Sound Classifier...
[KeywordSpotter] ✅ CoreML Sound Classifier loaded
[KeywordSpotter]    Model: SOSKeywordClassifier
[KeywordSpotter]    Classes: sos, oh_ess, noise, unknown
```

**If you see errors:**
```
[KeywordSpotter] ❌ Model loading failed: ...
```

Check the error message for details.

---

## 🎯 Next Steps After Successful Build

### Test SOS Detection

1. **Start listening:**
   - Launch the app
   - Enable SOS detection from the UI
   - Console should show: `🎤 Started listening for SOS keyword`

2. **Test detection:**
   - Say "SOS" clearly into the microphone
   - Console should show:
   ```
   [KeywordSpotter] 🔊 sos: 0.954 | SOS: 0.954
   [KeywordSpotter] 🚨 SOS DETECTED! Confidence: 0.915
   ```

3. **Test rejection of "oh ess":**
   - Say "oh ess" (should NOT trigger)
   - Console should show:
   ```
   [KeywordSpotter] 🔊 oh_ess: 0.892 | SOS: 0.108
   ```

---

## 📊 Model Info

- **File:** `SOSKeywordClassifier.mlmodel` (13KB)
- **Type:** MLSoundClassifier (Create ML)
- **Validation Accuracy:** 93.33%
- **Classes:** `sos`, `oh_ess`, `noise`, `unknown`
- **Sample Rate:** 22.05 kHz
- **Window:** ~1 second audio

---

## 🛠 Current Project State

```
✅ Duplicate model removed
✅ TensorFlowLite removed from Podfile
✅ KeywordSpotter.swift rewritten for CoreML
✅ Bridging header cleaned
✅ Derived data cleaned
✅ Pods reinstalled

📍 Model location: BEACON6/Resources/SOSKeywordClassifier.mlmodel
⏭️  Next: Add to Xcode and build
```

---

## Need Help?

If you encounter issues not covered here:

1. Check `COREML_MIGRATION_COMPLETE.md` for full migration details
2. Verify all old TensorFlowLite code has been removed
3. Make sure you're opening `.xcworkspace` not `.xcodeproj`
4. Try deleting `DerivedData` folder completely: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`

---

**Last Updated:** 2025-11-08
**Status:** Ready for Xcode integration
