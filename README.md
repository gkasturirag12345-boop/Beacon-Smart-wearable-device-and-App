# BEACON: Smart Wearable for Fall Detection and Emergency Alerts

A wrist-worn ESP32-C3 device and a SwiftUI iPhone app, connected only over Bluetooth Low Energy:
- the **wearable** measures heart rate, detects falls and wear state, handles the SOS button, and streams compressed
  microphone audio;
- the **iPhone** decodes that audio, spots the spoken keyword "SOS" with an on-device Core ML model, and raises
  emergency notifications.

*Student team project. Software lead: [@gkasturirag12345-boop](https://github.com/gkasturirag12345-boop). This
repository holds the final integrated firmware, iOS app and keyword-model training pipeline.*

## Problem
Older adults and lone workers who fall, or who suddenly need help, often cannot reach a phone. BEACON detects three
emergencies on the body: a fall, an abnormal heart rate, and a press of the SOS button. A spoken "SOS" is detected on
the phone. All of them become phone alerts without the wearer touching the phone.

## Architecture
```mermaid
flowchart LR
    subgraph W["Wearable: ESP32-C3 CodeCell (firmware/)"]
        BNO[BNO085 IMU] --> FD[fall detector<br/>2.5 g spike + stillness]
        MAX[MAX30105 PPG] --> HR[heart-rate + IR wear check]
        VCNL[VCNL4040 proximity] --> WEAR[wear detection]
        BTN[SOS button GPIO 3] --> BC[button controller<br/>1 press = alert, 2 = false alarm]
        MIC[I2S microphone] --> VAD[voice-activity gate] --> ADPCM[IMA ADPCM 4:1]
        FD & HR & WEAR & BC & ADPCM --> SCHED[FreeRTOS priority scheduler]
        PM[power manager<br/>light / deep sleep] -.- SCHED
    end
    SCHED -- "BLE GATT notify" --> BLE
    subgraph P["iPhone app: SwiftUI (ios/)"]
        BLE[BLEManager<br/>CoreBluetooth] --> HMS[HealthMonitoringService]
        BLE --> DEC[ADPCM decoder] --> KWS["KeywordSpotter<br/>SoundAnalysis + Core ML<br/>(sos / oh_ess / noise / unknown)"]
        KWS --> HMS
        HMS --> NOTIF[time-sensitive local notifications]
        HMS --> UI[dashboard, heart rate, fall detection, settings, test mode]
    end
```
**Processing is split:**
- The **wearable** computes heart rate, wear state, fall events, button events and audio compression.
- The **iPhone** decodes audio and runs keyword spotting. Alerting, location display and all user interface run
  there too.
- The phone sends commands back over the control characteristic. The firmware acts on `RESET_ALERT` and
  `TRIGGER_FALL` (test).

### BLE GATT profile (service `12345678-9012-3456-7890-1234567890AB`)
| Characteristic | UUID suffix | Direction | Content |
|---|---|---|---|
| Heart rate | `…90AC` | notify | beats per minute (uint8) |
| Alert status | `…90AD` | notify | text alerts: fall, heart-rate, manual SOS, false alarm, wear state |
| Control | `…90AE` | write | `RESET_ALERT`, `TRIGGER_FALL`; the app also sends `SOS_KEYWORD_<conf>` (see Limitations) |
| Audio | `…90AF` | notify | IMA-ADPCM compressed microphone audio (16 kHz base rate, 8 kHz in low-power mode) |

## Repository layout
```
├── firmware/Code_that_works2/   ESP32-C3 sketch: sensors, fall/HR/wear logic, button, audio, BLE, scheduler, power
│   └── sketch.yaml              pinned core and library versions (arduino-cli profile)
├── ios/                         Xcode project (BEACON6.xcodeproj, scheme "BEACON") and the SwiftUI app source
├── ml/                          Core ML keyword-classifier training: augmentation script, CreateML training script, report
└── docs/                        screenshots, development history
```

## Building
**Firmware** (arduino-cli 1.x; board definitions for the generic ESP32-C3):
```bash
cd firmware/Code_that_works2
arduino-cli compile --profile beacon        # installs the pinned core + libraries on first use
```
Verified 2026-11-18: esp32:esp32 3.3.1; the sketch uses 736 KB (56%) of flash and 27.7 KB of RAM.

**iOS app** (Xcode 26, iOS 26 SDK): open `ios/BEACON6.xcodeproj`, select the `BEACON` scheme, then set your own
development team and bundle identifier. The keyword model is not in the repository (see `ml/README.md`). Train it, or
place `SOSKeywordClassifier.mlmodel` in `ios/BEACON6/Resources/`, then build. Verified 2026-11-18: builds and runs on
the iPhone 17 simulator.

![The app on the iPhone simulator with no wearable connected](docs/images/ios_dashboard_offline.png)

*Simulator screenshot with no wearable connected: the dashboard shows Offline, and iOS is asking for microphone
access for on-device keyword detection. Hardware photos and a live demo are not included yet.*

## Results and validation
| What | Evidence | Status |
|---|---|---|
| Firmware compiles for ESP32-C3 with pinned libraries | `arduino-cli compile --profile beacon` | verified 2026-11-18 |
| iOS app builds and launches (simulator) | Xcode build, screenshot above | verified 2026-11-18 |
| Keyword model accuracy: 95.5% train, 93.2% validation, 90.7% test (4 classes) | `ml/training_report.txt` (CreateML, 2025-11-11) | as reported by CreateML; not re-run in this cleanup |
| End-to-end behaviour on hardware (falls, heart rate, SOS over BLE) | team testing during the project | not documented in this repository |

## Limitations
- **The wearable does not act on a voice SOS.** The iPhone detects the keyword, raises its own alert and sends
  `SOS_KEYWORD_<confidence>` to the device. The current firmware logs it as an unknown command.
- Alerts are local iPhone notifications. There is no automatic call, SMS or caregiver contact.
- The fall detector uses a fixed-threshold heuristic (impact over 2.5 g followed by stillness). It is not a trained
  model and has not been validated on a fall dataset.
- The keyword model's per-class metrics were not recorded (`ml/training_metrics.json` holds zeros). The model file
  and the audio datasets are not published.
- The power states are implemented, but battery life was not measured.

## Future work
Firmware handling of the voice-SOS command; caregiver notification (SMS or push through a backend); validation of
fall detection on recorded fall and non-fall activities; per-class keyword metrics; battery-life measurement.

## Development history
BEACON grew out of an earlier Design & Innovation Project prototype. It went through a Wi-Fi-plus-BLE generation, a
Node.js BLE bridge and an Edge Impulse keyword model before reaching this BLE-only, Core ML version. See
[`docs/history.md`](docs/history.md). The earlier component repositories are kept privately as historical
references and are not separate projects.

## Acknowledgements and licences
Third-party libraries and their licences are listed in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). This
repository does not include the Edge Impulse SDK or any Edge Impulse export.
