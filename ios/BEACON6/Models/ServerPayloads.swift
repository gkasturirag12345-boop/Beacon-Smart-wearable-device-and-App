
// JSON structures from ESP32-C3 health monitor
// Note: These payloads are for future REST API support (currently unused)
// Direct BLE communication uses binary/string formats instead

import Foundation

struct HeartRatePayload: Codable {
    let bpm: Double
}

struct SleepPayload: Codable {
    let duration: Double
    let qualityScore: Double
    let avgHeartRate: Double?
    let movementScore: Double?
}

struct FallPayload: Codable {
    let impact: Double
    let location: String?
}

struct AccelerometerPayload: Codable {
    let x: Double
    let y: Double
    let z: Double
}

