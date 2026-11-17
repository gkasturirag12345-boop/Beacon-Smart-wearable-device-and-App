# BEACON development history

BEACON went through several generations. The earlier work lives in separate private repositories, which are kept as
historical references only. This repository is the single, canonical BEACON project.

| Stage | What it was | Where |
|---|---|---|
| 1. Design & Innovation Project prototype | ESP32-C3 CodeCell sketch with the standard BLE heart-rate service, a Nano 33 IoT variant, and a small Python serial backend | private `dip-device-firmware` |
| 2. BEACON2 (Oct 2025) | First SwiftUI app: BLE heart rate, fall detection, notifications | see `history/ios_evolution_beacon2_to_beacon5.md` |
| 3. BEACON5 (Nov 2025) | Wi-Fi provisioning over BLE plus HTTP/WebSocket bridge (Node.js `noble`), voice SOS with an Edge Impulse/TFLite model, location, audio streaming | private `beacon-backend`, `beacon-sos-voice-ml` |
| 4. Final (BEACON6 app + `Code_that_works2` firmware, Nov 2025) | **BLE-only.** The Wi-Fi stack was removed from the firmware; Core ML (CreateML) replaced the Edge Impulse model; IMA-ADPCM audio; FreeRTOS priority scheduler; power states | this repository |
| Cleanup (2026-11-18) | Consolidated firmware, iOS and ML into one repository; removed the remaining unused Wi-Fi code from the iOS app; pinned firmware libraries | this repository |

The private `health-monitor-app` repository is a small Python analysis sketch (heart-rate variation, sleep scoring)
from the same period. It was never connected to the device.
