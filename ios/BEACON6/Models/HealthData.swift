//
//  HealthData.swift
//  BEACON
//
//  Created by Kasturiraj Guhan on 2/10/25.
//

import Foundation

struct HeartRateData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bpm: Double
    let isAlert: Bool
}

struct SleepQualityData: Identifiable {
    let id = UUID()
    let date: Date
    let duration: Double // hours
    let qualityScore: Double // 0-100
    let qualityRating: String // Excellent, Good, Fair, Poor
    let averageHeartRate: Double
    let movementScore: Double
    let feedback: String
}

struct FallDetectionEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let impactMagnitude: Double
    let location: String?
    let resolved: Bool
}

// HealthAlert is now defined in AlertManager.swift
