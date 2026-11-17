//
//  ConnectionMode.swift
//  BEACON
//
//  Connection mode shown in the UI. BEACON is BLE-only: the mode follows the BLE link state.
//

import Foundation

enum ConnectionMode: String, Codable {
    case ble = "BLE"
    case offline = "Offline"

    static func current(isConnected: Bool) -> ConnectionMode {
        isConnected ? .ble : .offline
    }

    var displayName: String {
        return self.rawValue
    }

    var iconName: String {
        switch self {
        case .ble:
            return "antenna.radiowaves.left.and.right"
        case .offline:
            return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .ble:
            return "blue"
        case .offline:
            return "red"
        }
    }

    var priority: Int {
        switch self {
        case .ble:
            return 2  // Fallback
        case .offline:
            return 3  // Lowest
        }
    }
}
