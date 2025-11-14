# SOS Keyword Detection - Threshold Tuning Guide

## Overview

This guide explains how to optimize detection thresholds to maximize true SOS detections while minimizing false alarms.

## Understanding Detection Parameters

### Current Configuration (KeywordSpotter.swift:37-39)

```swift
private let historySize: Int = 5  // Smoothing window (was 3)
private let detectionThreshold: Float = 0.8  // SOS confidence threshold
private let confidenceDeltaThreshold: Float = 0.3  // SOS must win by >0.3
```

### What These Parameters Control

| Parameter | Range | Effect | Trade-off |
|-----------|-------|--------|-----------|
| **detectionThreshold** | 0.0-1.0 | Minimum confidence to trigger SOS | Higher = fewer false alarms, but may miss weak detections |
| **confidenceDeltaThreshold** | 0.0-1.0 | How much SOS must beat 2nd-best class | Higher = more certain detections, stricter filtering |
| **historySize** | 1-10 | Number of windows averaged | Higher = smoother, but slower response time |
| **requiredConsecutiveDetections** | 1-5 | SOS must be detected N times in a row | Higher = more robust, but increased latency |

---

## The Precision-Recall Trade-off

### Metrics Explained

**True Positive (TP)**: SOS correctly detected when user said "SOS" ✅
**False Positive (FP)**: SOS detected when user said something else ❌
**False Negative (FN)**: SOS missed when user said "SOS" ⚠️ **DANGEROUS**
**True Negative (TN)**: Non-SOS correctly rejected ✅

**Precision** = TP / (TP + FP) → "How many detections are real?"
**Recall** = TP / (TP + FN) → "How many real SOSs are caught?"

### Goal for Emergency Detection
- **Recall ≥ 95%**: Must catch >95% of real emergencies
- **Precision ≥ 90%**: <10% false alarm rate is acceptable
- **F1-Score ≥ 0.92**: Balanced performance

---

## ROC Curve Analysis

### What is ROC?
Receiver Operating Characteristic (ROC) curve shows the trade-off between **True Positive Rate** (recall) and **False Positive Rate** at different thresholds.

### Creating ROC Curve

#### Step 1: Run Tests at Multiple Thresholds

```bash
cd ~/Documents/BEACON_Project

# Test thresholds from 0.5 to 0.95
for threshold in 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95; do
    echo "Testing threshold: $threshold"

    # Temporarily edit KeywordSpotter.swift
    # Change: private let detectionThreshold: Float = $threshold

    # Run performance test
    swift test_model_performance.swift \
        BEACON6_iOS/BEACON6/Resources/SOSKeywordClassifier.mlmodel \
        ~/Downloads/CreateML_SOS_Dataset/Testing \
        > results_threshold_${threshold}.txt
done
```

#### Step 2: Extract Metrics

Create `extract_metrics.sh`:
```bash
#!/bin/bash

echo "threshold,true_positives,false_positives,false_negatives,precision,recall,f1_score"

for file in results_threshold_*.txt; do
    threshold=$(echo $file | sed 's/results_threshold_//' | sed 's/.txt//')

    tp=$(grep "True Positives" $file | awk '{print $4}')
    fp=$(grep "False Positives" $file | awk '{print $4}')
    fn=$(grep "False Negatives" $file | awk '{print $4}')
    precision=$(grep "Precision" $file | grep "sos" | awk '{print $2}' | sed 's/%//')
    recall=$(grep "Recall" $file | grep "sos" | awk '{print $2}' | sed 's/%//')
    f1=$(grep "F1-Score" $file | grep "sos" | awk '{print $2}' | sed 's/%//')

    echo "$threshold,$tp,$fp,$fn,$precision,$recall,$f1"
done
```

Run:
```bash
chmod +x extract_metrics.sh
./extract_metrics.sh > roc_data.csv
```

#### Step 3: Plot ROC Curve (Python)

```python
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Load data
df = pd.read_csv('roc_data.csv')

# Calculate TPR and FPR
df['tpr'] = df['recall'] / 100  # True Positive Rate
df['fpr'] = df['false_positives'] / (df['false_positives'] + df['true_negatives'])

# Plot ROC Curve
plt.figure(figsize=(10, 8))
plt.plot(df['fpr'], df['tpr'], 'b-o', linewidth=2, markersize=8, label='SOS Detector')
plt.plot([0, 1], [0, 1], 'r--', linewidth=1, label='Random Classifier')

# Mark optimal point
optimal_idx = df['f1_score'].idxmax()
optimal_threshold = df.loc[optimal_idx, 'threshold']
plt.plot(df.loc[optimal_idx, 'fpr'], df.loc[optimal_idx, 'tpr'],
         'go', markersize=15, label=f'Optimal (threshold={optimal_threshold})')

# Calculate AUC (Area Under Curve)
from sklearn.metrics import auc
auc_score = auc(df['fpr'].sort_values(), df['tpr'][df['fpr'].sort_index()])

plt.xlabel('False Positive Rate', fontsize=14)
plt.ylabel('True Positive Rate (Recall)', fontsize=14)
plt.title(f'ROC Curve - SOS Keyword Detector (AUC={auc_score:.3f})', fontsize=16)
plt.legend(fontsize=12)
plt.grid(True, alpha=0.3)
plt.xlim([0, 1])
plt.ylim([0, 1])
plt.tight_layout()
plt.savefig('roc_curve.png', dpi=300)
plt.show()

print(f"\n📊 Optimal Threshold: {optimal_threshold}")
print(f"   TPR (Recall): {df.loc[optimal_idx, 'tpr']:.2%}")
print(f"   FPR: {df.loc[optimal_idx, 'fpr']:.2%}")
print(f"   Precision: {df.loc[optimal_idx, 'precision']:.2f}%")
print(f"   F1-Score: {df.loc[optimal_idx, 'f1_score']:.2f}%")
```

---

## Precision-Recall Curve

### Creating PR Curve

```python
# Plot Precision-Recall Curve
plt.figure(figsize=(10, 8))
plt.plot(df['recall'] / 100, df['precision'] / 100, 'b-o',
         linewidth=2, markersize=8, label='SOS Detector')

# Mark optimal point
plt.plot(df.loc[optimal_idx, 'recall'] / 100, df.loc[optimal_idx, 'precision'] / 100,
         'go', markersize=15, label=f'Optimal (F1={df.loc[optimal_idx, "f1_score"]:.1f}%)')

# Add threshold labels
for i, row in df.iterrows():
    plt.annotate(f"{row['threshold']:.2f}",
                 (row['recall'] / 100, row['precision'] / 100),
                 textcoords="offset points", xytext=(5, 5), fontsize=9)

plt.xlabel('Recall (True Positive Rate)', fontsize=14)
plt.ylabel('Precision', fontsize=14)
plt.title('Precision-Recall Curve - SOS Keyword Detector', fontsize=16)
plt.legend(fontsize=12)
plt.grid(True, alpha=0.3)
plt.xlim([0, 1])
plt.ylim([0, 1])
plt.tight_layout()
plt.savefig('precision_recall_curve.png', dpi=300)
plt.show()
```

---

## Threshold Selection Strategy

### Scenario-Based Recommendations

#### 1. **Emergency Medical Device (Current Use Case)**
**Priority**: Catch all real emergencies (high recall)

Recommended settings:
```swift
private let detectionThreshold: Float = 0.70  // Lower threshold
private let confidenceDeltaThreshold: Float = 0.25  // Relaxed delta
private let requiredConsecutiveDetections: Int = 2  // Still require confirmation
```

**Expected metrics**:
- Recall: 98-99% (catches nearly all SOS)
- Precision: 85-90% (10-15% false alarm rate - acceptable for safety)
- F1-Score: 0.91-0.93

**Justification**: Missing a real emergency is unacceptable. False alarms can be filtered by user or double-button press.

---

#### 2. **General Consumer App**
**Priority**: Balance between detection and user annoyance

Recommended settings:
```swift
private let detectionThreshold: Float = 0.80  // Current setting
private let confidenceDeltaThreshold: Float = 0.30  // Current setting
private let requiredConsecutiveDetections: Int = 2
```

**Expected metrics**:
- Recall: 95-97%
- Precision: 92-95%
- F1-Score: 0.93-0.96

**Justification**: Good balance - catches most emergencies with low false alarm rate.

---

#### 3. **High-Security / Low-Tolerance for False Alarms**
**Priority**: Minimize false alarms (high precision)

Recommended settings:
```swift
private let detectionThreshold: Float = 0.90  // Very strict
private let confidenceDeltaThreshold: Float = 0.40  // SOS must clearly win
private let requiredConsecutiveDetections: Int = 3  // Triple confirmation
```

**Expected metrics**:
- Recall: 85-90% (misses some quiet/distressed SOSs)
- Precision: 98-99% (very few false alarms)
- F1-Score: 0.91-0.93

**Justification**: For scenarios where false alarms trigger expensive response (e.g., 911 dispatch).

---

## Tuning Confidence Delta Threshold

### What is Confidence Delta?

The delta measures how much the SOS confidence beats the second-best class:

```
delta = confidence(SOS) - confidence(2nd_best)
```

### Example Console Logs

**Good detection** (delta = 0.72):
```
[KeywordSpotter] 🔊 sos: 0.954 | SOS: 0.954 | 2nd: noise(0.234) | Δ: 0.720
```
SOS wins by huge margin → Very confident detection ✅

**Borderline detection** (delta = 0.15):
```
[KeywordSpotter] 🔊 sos: 0.725 | SOS: 0.725 | 2nd: oh_ess(0.575) | Δ: 0.150
```
SOS barely wins → Model is uncertain ⚠️

**Failed detection** (delta = -0.20):
```
[KeywordSpotter] 🔊 oh_ess: 0.892 | SOS: 0.108 | 2nd: oh_ess(0.892) | Δ: -0.784
```
"oh ess" wins → Correctly rejected ✅

### Delta Threshold Recommendations

| Delta Threshold | Effect | Use Case |
|----------------|--------|----------|
| 0.1 | Very lenient - allows close calls | Testing, data collection |
| 0.2 | Lenient - SOS needs slight lead | High recall priority |
| **0.3** | **Moderate - current setting** | **Balanced (recommended)** |
| 0.4 | Strict - SOS must clearly win | High precision priority |
| 0.5 | Very strict - only obvious SOS | Low false alarm tolerance |

### Testing Delta Thresholds

Modify KeywordSpotter.swift:
```swift
// Test different delta thresholds
private let confidenceDeltaThreshold: Float = 0.2  // Try: 0.1, 0.2, 0.3, 0.4, 0.5
```

Monitor console output:
```bash
# Look for rejection patterns
grep "Reset consecutive" beacon_logs.txt

# Count how many borderline cases pass/fail
grep "Δ:" beacon_logs.txt | awk '{print $NF}' | sort -n
```

---

## Live Tuning During Development

### Step 1: Enable Debug Logging

Add to KeywordSpotter.swift:
```swift
@Published var debugInfo: String = ""

// In request() method, publish debug data:
DispatchQueue.main.async { [weak self] in
    self?.debugInfo = """
    Conf: \(String(format: "%.3f", smoothedConfidence))
    Delta: \(String(format: "%.3f", confidenceDelta))
    Top: \(topClass)
    Consecutive: \(consecutiveSOSDetections)/\(requiredConsecutiveDetections)
    """
}
```

### Step 2: Add Debug UI (KeywordSpottingView.swift)

```swift
// Add to KeywordSpottingView
VStack {
    Text("Debug Info")
        .font(.caption)
        .foregroundColor(.gray)

    Text(keywordSpotter.debugInfo)
        .font(.system(.caption, design: .monospaced))
        .padding(8)
        .background(Color.black.opacity(0.1))
        .cornerRadius(4)
}
.padding()
```

### Step 3: Interactive Threshold Adjustment

```swift
// Add sliders to KeywordSpottingView
VStack {
    Text("Detection Threshold: \(detectionThreshold, specifier: "%.2f")")
    Slider(value: $detectionThreshold, in: 0.5...0.95, step: 0.05)
        .onChange(of: detectionThreshold) { newValue in
            // Update KeywordSpotter threshold dynamically
            keywordSpotter.updateThreshold(newValue)
        }

    Text("Delta Threshold: \(deltaThreshold, specifier: "%.2f")")
    Slider(value: $deltaThreshold, in: 0.1...0.5, step: 0.05)
        .onChange(of: deltaThreshold) { newValue in
            keywordSpotter.updateDeltaThreshold(newValue)
        }
}
```

Add to KeywordSpotter.swift:
```swift
// Make thresholds mutable for live tuning
private var detectionThreshold: Float = 0.8
private var confidenceDeltaThreshold: Float = 0.3

func updateThreshold(_ newThreshold: Float) {
    detectionThreshold = newThreshold
    print("[KeywordSpotter] 🎚️ Threshold updated: \(newThreshold)")
}

func updateDeltaThreshold(_ newDelta: Float) {
    confidenceDeltaThreshold = newDelta
    print("[KeywordSpotter] 🎚️ Delta threshold updated: \(newDelta)")
}
```

---

## Performance Monitoring in Production

### Metrics to Track

Create PerformanceTracker.swift:
```swift
class PerformanceTracker {
    static let shared = PerformanceTracker()

    private var detectionLog: [(Date, String, Float, Bool)] = []

    func logDetection(timestamp: Date, type: String, confidence: Float, confirmed: Bool) {
        detectionLog.append((timestamp, type, confidence, confirmed))

        // Save to UserDefaults or file for later analysis
        if detectionLog.count % 100 == 0 {
            exportLog()
        }
    }

    func exportLog() {
        let csv = detectionLog.map { timestamp, type, conf, confirmed in
            "\(timestamp.timeIntervalSince1970),\(type),\(conf),\(confirmed ? 1 : 0)"
        }.joined(separator: "\n")

        // Save CSV for analysis
        let filename = "detection_log_\(Date().timeIntervalSince1970).csv"
        try? csv.write(toFile: filename, atomically: true, encoding: .utf8)
    }
}
```

### Weekly Performance Review

Analyze logs to find:
1. **False Positive Patterns**: What triggers false alarms?
2. **Missed Detections**: What characteristics do missed SOSs share?
3. **Confidence Distribution**: Are we too strict or too lenient?

```python
import pandas as pd
import matplotlib.pyplot as plt

# Load detection logs
df = pd.read_csv('detection_log_*.csv', names=['timestamp', 'type', 'confidence', 'confirmed'])

# Plot confidence distribution
plt.figure(figsize=(12, 6))
for detection_type in ['SOS', 'oh_ess', 'noise', 'unknown']:
    subset = df[df['type'] == detection_type]
    plt.hist(subset['confidence'], alpha=0.5, label=detection_type, bins=20)

plt.axvline(0.8, color='red', linestyle='--', label='Current Threshold')
plt.xlabel('Confidence')
plt.ylabel('Frequency')
plt.title('Detection Confidence Distribution')
plt.legend()
plt.savefig('confidence_distribution.png')
plt.show()

# Find optimal threshold based on real-world data
# (Requires manual labeling of false positives)
```

---

## Final Recommendations

### For BEACON6 Medical Device

**Recommended Configuration:**
```swift
private let historySize: Int = 5  // ✅ Current (good)
private let detectionThreshold: Float = 0.75  // ⬇️ Lower from 0.80
private let confidenceDeltaThreshold: Float = 0.28  // ⬇️ Lower from 0.30
private let requiredConsecutiveDetections: Int = 2  // ✅ Current (good)
private let minDetectionInterval: TimeInterval = 2.0  // ✅ Current (good)
```

**Expected Performance:**
- **Recall**: 97-99% (catches almost all emergencies)
- **Precision**: 88-92% (8-12% false alarm rate)
- **F1-Score**: 0.92-0.95

**Justification**: For medical emergency detection, it's better to have a few false alarms than miss a real emergency.

---

## Testing Checklist

Before deploying new thresholds:

- [ ] Run full test suite with `test_model_performance.swift`
- [ ] Verify recall ≥ 95% for SOS class
- [ ] Verify false positive rate ≤ 10%
- [ ] Test with 20+ real users saying "SOS" in various conditions
- [ ] Test with 50+ "oh ess" utterances (should not trigger)
- [ ] Test in noisy environments (traffic, cafe, outdoor)
- [ ] Measure detection latency (<500ms acceptable)
- [ ] Review console logs for borderline cases
- [ ] Get user feedback on false alarm annoyance level

---

## References

- **ROC Curve**: https://en.wikipedia.org/wiki/Receiver_operating_characteristic
- **Precision-Recall**: https://scikit-learn.org/stable/auto_examples/model_selection/plot_precision_recall.html
- **F1-Score**: https://en.wikipedia.org/wiki/F-score

---

**Last Updated**: 2025-11-08
**Current Thresholds**: 0.80 (detection), 0.30 (delta)
**Recommended**: 0.75 (detection), 0.28 (delta) for medical use
