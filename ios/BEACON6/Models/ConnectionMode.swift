//
//  ConnectionMode.swift
//  BEACON
//
//  Connection mode enum for network coordination
//

import Foundation

enum ConnectionMode: String, Codable {
    case wifi = "WiFi"
    case ble = "BLE"
    case offline = "Offline"

    var displayName: String {
        return self.rawValue
    }

    var iconName: String {
        switch self {
        case .wifi:
            return "wifi"
        case .ble:
            return "antenna.radiowaves.left.and.right"
        case .offline:
            return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .wifi:
            return "green"
        case .ble:
            return "blue"
        case .offline:
            return "red"
        }
    }

    var priority: Int {
        switch self {
        case .wifi:
            return 1  // Highest priority
        case .ble:
            return 2  // Fallback
        case .offline:
            return 3  // Lowest
        }
    }
}
