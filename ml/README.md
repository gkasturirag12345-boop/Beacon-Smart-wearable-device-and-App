# SOS keyword classifier (Core ML)

The iPhone app spots the word "SOS" in audio streamed from the wearable. It uses Apple's SoundAnalysis framework with a
CreateML `MLSoundClassifier` that has four classes: `sos`, `oh_ess` (similar-sounding speech), `noise` and `unknown`.

| File | Purpose |
|---|---|
| `augment_sos_training_data.py` | Expands a labelled dataset: speed, pitch and volume changes, stress/mumble/slur simulation, background noise (`pip install -r requirements.txt`) |
| `train_sos_classifier.swift` | Trains the classifier with CreateML from `<dataset>/Training` and `<dataset>/Testing`, and writes the model and its metrics |
| `training_report.txt`, `training_metrics.json` | Report of the training run of 2025-11-11 (train 95.53%, validation 93.15%, test 90.74%); per-class metrics were not recorded |

```bash
python3 augment_sos_training_data.py --input /path/to/CreateML_SOS_Dataset --output /path/to/Augmented_SOS_Dataset
swift train_sos_classifier.swift --dataset /path/to/Augmented_SOS_Dataset
cp SOSKeywordClassifier.mlmodel ../ios/BEACON6/Resources/
```

**Not in this repository:**
- the audio datasets;
- the trained `SOSKeywordClassifier.mlmodel`. Its training data's provenance and consent have not been cleared for
  publication, so it is git-ignored;
- the earlier Edge Impulse keyword model. It needs a paid Edge Impulse subscription and is not used by the app.
