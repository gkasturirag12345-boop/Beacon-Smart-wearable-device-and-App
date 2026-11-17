# Third-party software

The firmware is built against these libraries. They are installed by arduino-cli and are **not** vendored into this
repository. Versions are pinned in `firmware/Code_that_works2/sketch.yaml`.

| Library | Version | Licence |
|---|---|---|
| Arduino core for ESP32 (Espressif) | 3.3.1 | LGPL-2.1-or-later (with components under other licences) |
| NimBLE-Arduino (h2zero) | 2.3.6 | Apache-2.0 |
| Adafruit BNO08x | 1.2.5 | BSD-3-Clause; bundles the CEVA SH-2 driver (Apache-2.0) |
| Adafruit VCNL4040 | 1.2.0 | BSD-3-Clause |
| Adafruit BusIO | 1.17.4 | MIT |
| Adafruit Unified Sensor | 1.1.15 | Apache-2.0 |
| SparkFun MAX3010x Pulse and Proximity Sensor Library | 1.1.2 | MIT (SparkFun); `heartRate.cpp` keeps Maxim Integrated's copyright notice |

The iOS app uses only Apple system frameworks (SwiftUI, CoreBluetooth, SoundAnalysis, Core ML, AVFoundation,
CoreLocation, UserNotifications). The ML scripts use librosa, soundfile, NumPy and SciPy (see `ml/requirements.txt`).

Check each licence against the library's own repository before redistributing binaries.
