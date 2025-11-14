# SOS Keyword Spotting - Data Collection Guide

## Goal
Improve model accuracy from **93.33% → 98%+** by collecting high-quality, diverse training data.

## Current Dataset Analysis

### Class Distribution (Before)
| Class | Training | Testing | Total | Percentage |
|-------|----------|---------|-------|------------|
| unknown | 1,026 | 263 | 1,289 | 38.8% |
| sos | 683 | 164 | 847 | 25.5% |
| oh_ess | 519 | 132 | 651 | 19.6% |
| noise | 418 | 119 | 537 | 16.1% |
| **TOTAL** | 2,646 | 678 | 3,324 | 100% |

### Problems Identified
1. **Class imbalance**: `unknown` has 50% more samples than `sos`
2. **Limited SOS samples**: Only 847 total (need 1,500+ for robust detection)
3. **Acoustic confusion**: "SOS" vs "oh ess" are phonetically similar
4. **Low diversity**: Samples may lack variation in:
   - Speakers (age, gender, accent)
   - Recording conditions (quiet/noisy, indoor/outdoor)
   - Emotional states (calm/distressed/shouting)
   - Microphone positions (close/far, muffled/clear)

---

## Target Dataset (After Collection)

### Recommended Distribution
| Class | Training | Testing | Total | Target |
|-------|----------|---------|-------|--------|
| sos | 1,200 | 300 | 1,500 | ✅ Primary focus |
| oh_ess | 800 | 200 | 1,000 | ⚠️ Add confusing examples |
| noise | 800 | 200 | 1,000 | ✅ Environmental variety |
| unknown | 800 | 200 | 1,000 | ✅ Reduce imbalance |
| **TOTAL** | 3,600 | 900 | 4,500 | 135% increase |

---

## Collection Priorities

### Priority 1: More "SOS" Samples (Need +653 samples)

#### Recording Guidelines

**A. Speaker Diversity**
Recruit 20+ speakers with variation in:
- **Age groups**: Children (6-12), teens (13-19), adults (20-60), seniors (60+)
- **Gender**: Male, female, non-binary
- **Accents**: American, British, Australian, Indian, Chinese, etc.
- **Voice characteristics**: High-pitched, low-pitched, raspy, clear

**B. Emotional States** (Critical for emergency detection!)
Record each speaker saying "SOS" in different emotional states:
- **Calm/neutral**: "ess oh ess" (clear pronunciation)
- **Urgent**: "SOS!" (raised voice, fast)
- **Distressed**: "SOS! Help!" (panicked, shaky voice)
- **Weak/quiet**: "...sos..." (elderly person, low energy)
- **Shouting**: "SOS!!!" (loud, strained)
- **Muffled**: "sos" (hand over mouth, through cloth)

**C. Recording Environments**
Capture in various acoustic conditions:
- **Quiet room** (baseline, ~30dB background)
- **Living room** (TV/radio on, ~50dB)
- **Street noise** (traffic, pedestrians, ~70dB)
- **Cafe/restaurant** (conversation, dishes, ~65dB)
- **Outdoors** (wind, birds, traffic, ~60dB)

**D. Microphone Positions**
Vary distance and angle:
- **Close-field** (0.2m - phone near face)
- **Medium** (0.5m - arm's length)
- **Far-field** (1-2m - across room)
- **Off-axis** (45°, 90° angles)
- **Pocket/muffled** (phone in pocket/bag)

**E. Speech Variations**
- **Spelling it out**: "S-O-S" (individual letters)
- **Repeated**: "SOS SOS SOS" (multiple times)
- **Embedded**: "Please help, SOS!" (in sentence)
- **Fast**: "sososos" (rapid repetition)
- **Slow**: "S... O... S..." (deliberate, slow)

---

### Priority 2: Better "oh_ess" Negatives (Need +481 samples)

**Goal**: Reduce false positives by training model to reject phonetically similar phrases.

#### Record confusing alternatives:
- "oh ess" (spelled out)
- "O S" (just two letters)
- "oh yes"
- "oh ess oh" (partial)
- "go S" / "no S" (similar sounds)
- "so ess" (reversed)
- "low S" / "show S" (rhyming words)
- "sos-like" non-words: "oss", "soss", "ohss"

#### Record in same conditions as "SOS":
- Use same speakers
- Same environments
- Same emotional states
- Same microphone positions

---

### Priority 3: Diverse "noise" Samples (Need +463 samples)

**Goal**: Teach model to ignore non-speech sounds.

#### Categories to collect:

**A. Environmental Sounds**
- Traffic (cars, buses, motorcycles)
- Wind blowing (light breeze, strong gusts)
- Rain (light drizzle, heavy downpour)
- Birds chirping
- Dogs barking
- Sirens (ambulance, police, fire truck)
- Construction noise (drilling, hammering)
- Kitchen sounds (dishes, water, cooking)

**B. Indoor Ambient**
- Air conditioning / heating
- Fan noise
- Computer/laptop fan
- Refrigerator hum
- Electrical buzzing
- Door closing/opening
- Footsteps
- Keyboard typing

**C. Human Non-Speech**
- Coughing
- Sneezing
- Breathing (heavy breathing, panting)
- Laughing
- Crying
- Sighing
- Throat clearing
- Humming (non-verbal)

**D. Electronic Sounds**
- Phone ringing
- Notification sounds
- Alarms (clock, phone)
- TV audio (muffled speech)
- Radio static
- Music (instrumental only)

---

### Priority 4: Better "unknown" Class (Need -226 samples)

**Goal**: Reduce class imbalance while keeping useful negative examples.

#### What to include:
- Common phrases that might be confused with "SOS"
- Emergency-related words: "help", "emergency", "call 911"
- Random speech: Conversation snippets (without "SOS")
- Partial words: "so", "ess", "oh"
- Numbers that sound similar: "zero S", "S O two"

#### What to remove:
- Review existing 1,026 samples
- Remove duplicates or very similar samples
- Keep only representative diverse examples

---

## Recording Technical Specifications

### Audio Format Requirements
- **Sample rate**: 22,050 Hz (matches model training)
- **Channels**: Mono
- **Bit depth**: 16-bit
- **Format**: WAV (uncompressed)
- **Duration**: 0.7-1.0 seconds per clip
- **Silence padding**: 0.1s before/after utterance

### Signal Quality
- **SNR (Signal-to-Noise Ratio)**: >10dB minimum
- **Clipping**: Avoid (keep peaks below -3dB)
- **Normalization**: Peak normalize to -1dB after recording

---

## Recording Tools

### Option A: Mobile App (Recommended for field recording)

Use iOS Voice Memos or Android Sound Recorder:
1. **Settings**:
   - Quality: Lossless/High
   - Format: WAV if available (or convert AAC→WAV later)
2. **Process**:
   - Record in batches (10-20 samples)
   - Label immediately: `SOS_speaker01_urgent.wav`
   - Transfer to computer for processing

### Option B: Computer (Best for controlled environment)

Use Audacity (free, cross-platform):
1. **Project Rate**: Set to 22,050 Hz
2. **Recording**:
   - Click Record
   - Say keyword
   - Stop
   - Select audio → Trim silence → Export
3. **Batch export**: File → Export Multiple

### Option C: Python Script (For automation)

```python
import sounddevice as sd
import soundfile as sf
import numpy as np

def record_sample(filename, duration=1.0, sr=22050):
    print(f"Recording {filename}... (say SOS now)")
    audio = sd.rec(int(duration * sr), samplerate=sr, channels=1, dtype='float32')
    sd.wait()

    # Normalize
    audio = audio / np.max(np.abs(audio))

    # Save as WAV
    sf.write(filename, audio, sr)
    print(f"✅ Saved: {filename}")

# Usage:
for i in range(10):
    input("Press Enter when ready...")
    record_sample(f"SOS_batch1_{i:03d}.wav")
```

---

## File Naming Convention

### Format: `{CLASS}_{SPEAKER}_{CONDITION}_{INDEX}.wav`

**Examples:**
- `SOS_speaker01_calm_quiet_001.wav`
- `SOS_speaker01_urgent_street_002.wav`
- `SOS_speaker02_distressed_indoor_001.wav`
- `oh_ess_speaker03_neutral_quiet_001.wav`
- `noise_traffic_highway_001.wav`
- `unknown_conversation_cafe_001.wav`

**Metadata fields:**
- **CLASS**: `SOS`, `oh_ess`, `noise`, `unknown`
- **SPEAKER**: `speaker01` through `speaker20+` (or `environmental` for noise)
- **CONDITION**: `calm`, `urgent`, `distressed`, `weak`, `shouting`, `muffled`, `quiet`, `street`, `indoor`, etc.
- **INDEX**: 3-digit number `001-999`

---

## Data Collection Workflow

### Phase 1: Recruit Speakers (Week 1)
1. Find 20+ diverse volunteers (friends, family, online)
2. Provide recording instructions
3. Send them the recording script (see below)

### Phase 2: Batch Recording (Week 1-2)
1. **Session 1**: Quiet environment baseline
   - Each speaker: 10× calm "SOS", 10× "oh ess"
   - Expected: 20 speakers × 20 samples = 400 samples

2. **Session 2**: Emotional variations
   - Each speaker: 5× urgent, 5× distressed, 5× weak
   - Expected: 20 speakers × 15 samples = 300 samples

3. **Session 3**: Environmental variations
   - Subset of 10 speakers in noisy environments
   - 10× street, 10× cafe, 10× outdoor
   - Expected: 10 speakers × 30 samples = 300 samples

4. **Session 4**: Noise collection
   - Record environmental sounds (no speakers needed)
   - Target: 500 samples (1-2 days of collection)

### Phase 3: Data Processing (Week 2)
1. **Quality check**: Listen to all samples, remove bad recordings
2. **Trim silence**: Remove leading/trailing silence (keep 0.1s padding)
3. **Normalize**: Peak normalize all files to -1dB
4. **Convert format**: Ensure all are 22,050 Hz, mono, 16-bit WAV
5. **Organize**: Sort into folders by class

### Phase 4: Dataset Preparation (Week 2)
1. Run `reorganize_dataset.swift` with new data
2. Verify train/test split (80/20)
3. Check class balance

---

## Recording Script (For Speakers)

**Send this to volunteers:**

```
Hi! Thank you for helping improve the SOS detection system.

WHAT TO RECORD:
- Say "SOS" (like "ess-oh-ess") 10 times in a calm, clear voice
- Say "SOS" 5 times like you're in an emergency (urgent, stressed)
- Say "oh ess" (two separate words) 10 times in a calm voice

RECORDING SETTINGS:
- Use your phone's voice recorder app
- Find a quiet room (turn off TV/music)
- Hold phone 20cm (~8 inches) from your mouth
- Speak clearly at normal volume

NAMING FILES:
- Please name files: YourName_SOS_001.wav, YourName_SOS_002.wav, etc.
- For "oh ess": YourName_ohess_001.wav

SEND TO:
- Email: [your-email@example.com]
- Or upload to: [shared folder link]

TIME REQUIRED: ~10 minutes

Thank you! Your voice will help save lives in emergency situations.
```

---

## Quality Control Checklist

Before adding sample to dataset:
- [ ] Correct format (22,050 Hz, mono, 16-bit WAV)
- [ ] Duration 0.7-1.0 seconds
- [ ] No clipping (peaks below -3dB)
- [ ] Clear utterance (audible keyword)
- [ ] Correct label matches audio content
- [ ] No excessive silence (>0.2s before/after)
- [ ] Background noise appropriate for class
- [ ] File named correctly per convention

---

## Expected Results After Collection

### Dataset Statistics (After)
- **Total samples**: 4,500 (35% increase)
- **Training samples**: 3,600
- **Testing samples**: 900
- **Class balance**: ~25% per class (balanced)

### Expected Model Performance
- **Validation accuracy**: 93.33% → **98%+**
- **SOS detection rate**: >95% (true positives)
- **False positive rate**: <1% (false alarms)
- **Confusion reduction**: "SOS" vs "oh ess" delta >0.4

### Timeline
- **Week 1**: Speaker recruitment + baseline recording (800 samples)
- **Week 2**: Environmental + noise recording (700 samples)
- **Week 2-3**: Processing + retraining
- **Week 3**: Testing + deployment

---

## Post-Collection Next Steps

1. **Retrain model**:
   ```bash
   cd ~/Documents/BEACON_Project
   swift reorganize_dataset.swift  # Organize new data
   swift train_sos_classifier.swift  # Retrain with new dataset
   ```

2. **Evaluate performance**:
   - Test on hold-out set (900 samples)
   - Measure confusion matrix
   - Check accuracy per class

3. **Deploy to app**:
   ```bash
   cp SOSKeywordClassifier.mlmodel BEACON6_iOS/BEACON6/Resources/
   # Open Xcode and rebuild
   ```

4. **Monitor in production**:
   - Use `getPerformanceStats()` in KeywordSpotter
   - Track false positive rate
   - Collect failure cases for next iteration

---

## Resources

### Free Audio Tools
- **Audacity**: https://www.audacityteam.org/ (recording + editing)
- **SoX**: https://sox.sourceforge.net/ (batch processing CLI)
- **ffmpeg**: https://ffmpeg.org/ (format conversion)

### Sample Download Sources (Public Domain)
- **Freesound**: https://freesound.org/ (environmental sounds)
- **OpenSLR**: https://www.openslr.org/ (speech datasets)
- **Google AudioSet**: https://research.google.com/audioset/ (sound events)

### Python Libraries
```bash
pip install sounddevice soundfile numpy scipy
```

---

## Contact & Support

**Questions?** Check:
- `COREML_MIGRATION_COMPLETE.md` - Model training details
- `SOS_VOICE_INTEGRATION.md` - Integration guide
- `train_sos_classifier.swift` - Training script

**Issues?**
- Model accuracy not improving → Check class balance
- Recording quality poor → Adjust microphone settings
- Samples rejected by Create ML → Check duration/format

---

**Last Updated**: 2025-11-08
**Version**: 1.0
**Status**: Ready for data collection
