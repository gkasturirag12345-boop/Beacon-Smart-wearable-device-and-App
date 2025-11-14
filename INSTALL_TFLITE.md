# Install TensorFlow Lite in Xcode

## Method 1: Swift Package Manager (RECOMMENDED)

1. **Open Xcode project:**
   ```bash
   open /Users/kasturirajguhan/Documents/BEACON_Project/BEACON_iOS/BEACON_5.xcodeproj
   ```

2. **Add Package Dependency:**
   - In Xcode menu: **File → Add Package Dependencies...**
   - Paste this URL:
     ```
     https://github.com/tensorflow/tensorflow
     ```
   - Click **Add Package**

3. **Select Package Products:**
   - Check: ☑️ **TensorFlowLiteSwift**
   - Click **Add Package**

4. **Wait for installation** (30-60 seconds)

5. **Build project:**
   - Press **⌘ + B**
   - Error should disappear!

---

## Method 2: CocoaPods (Alternative)

### Step 1: Install CocoaPods (if not installed)

```bash
sudo gem install cocoapods
```

### Step 2: Create Podfile

```bash
cd /Users/kasturirajguhan/Documents/BEACON_Project/BEACON_iOS

cat > Podfile << 'EOF'
platform :ios, '15.0'
use_frameworks!

target 'BEACON' do
  pod 'TensorFlowLiteSwift', '~> 2.14.0'
end
EOF
```

### Step 3: Install Pods

```bash
pod install
```

### Step 4: Close Xcode and open workspace

```bash
# Close Xcode project first!
open BEACON_5.xcworkspace
```

**Important:** After using CocoaPods, always open `.xcworkspace` instead of `.xcodeproj`

---

## Verification

After installation, check that import works:

1. Open `KeywordSpotterTFLite.swift`
2. Line 14 should show no error: `import TensorFlowLite`
3. Build succeeds: ⌘ + B

---

## Troubleshooting

### "No such module 'TensorFlowLite'" still appears

**Solution:**
1. Clean build: **Product → Clean Build Folder** (⌘ + Shift + K)
2. Restart Xcode
3. Build again: ⌘ + B

### Swift Package Manager fails

**Solution:**
1. Check internet connection
2. Try CocoaPods method instead
3. Or manually download: https://github.com/tensorflow/tensorflow/releases

---

## Recommended: Use Core ML Instead

Since TensorFlow Lite is giving you issues, this is a **perfect time to switch to Core ML**!

Core ML advantages:
- ✅ Native Apple framework (no external dependencies)
- ✅ 2-3x faster inference
- ✅ Better battery efficiency
- ✅ Easier to install

**Follow the guide:**
```bash
open /Users/kasturirajguhan/Documents/BEACON_Project/ml_conversion/EDGE_IMPULSE_COREML_GUIDE.md
```

Then use `KeywordSpotter.swift` instead of `KeywordSpotterTFLite.swift`!
