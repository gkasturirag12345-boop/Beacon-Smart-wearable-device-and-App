//
//  KeywordDetection.swift
//  BEACON
//
//  Shared model for keyword detection results
//  Used by both KeywordSpotter.swift and KeywordSpotterTFLite.swift
//

import Foundation

/// Keyword detection result
struct KeywordDetection: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date  // When detection object was created (alert time)
    let detectionTimestamp: Date  // When SOS was actually detected by ML model
    let keyword: String  // "SOS", "noises", "unknown"
    let confidence: Float
    let threshold: Float = 0.3  // Lowered from 0.6 for debugging

    var isDetected: Bool {
        return keyword == "SOS" && confidence >= threshold
    }

    /// Latency from detection to alert creation (in milliseconds)
    var latencyMs: Double {
        return timestamp.timeIntervalSince(detectionTimestamp) * 1000
    }

    /// Formatted detection time with milliseconds
    var detectionTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: detectionTimestamp)
    }

    static func == (lhs: KeywordDetection, rhs: KeywordDetection) -> Bool {
        return lhs.id == rhs.id
    }
}
