//
//  WiFiCommunicationManager.swift
//  BEACON
//
//  WiFi Communication Manager for ESP32-C3
//  Handles HTTP communication, ping monitoring, and automatic failover detection
//

import Foundation
import Combine

struct SensorDataResponse: Codable {
    let deviceId: String
    let timestamp: Int
    let uptime: Int
    let heartRate: Int
    let fallDetected: Bool
    let impactMagnitude: Double
    let wearStatus: String
    let wifiRSSI: Int
    let wifiIP: String
    let batteryLevel: Int
}

class WiFiCommunicationManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var lastPingTime: Date?
    @Published var lastSensorData: SensorDataResponse?
    @Published var connectionQuality: Int = 0  // 0-100

    // MARK: - Private Properties
    private var deviceIP: String?
    private var pingTimer: Timer?
    private let pingInterval: TimeInterval = 5.0
    private var consecutiveFailures = 0
    private let maxFailures = 3

    // MARK: - Callbacks
    var onConnectionLost: (() -> Void)?
    var onConnectionRestored: (() -> Void)?
    var onSensorDataReceived: ((SensorDataResponse) -> Void)?

    // MARK: - Initialization
    init() {
        print("[WiFiComm] WiFi Communication Manager initialized")
    }

    // MARK: - Connection Management
    func startMonitoring(ip: String) {
        guard deviceIP != ip || pingTimer == nil else {
            print("[WiFiComm] Already monitoring IP: \(ip)")
            return
        }

        deviceIP = ip
        consecutiveFailures = 0

        print("========================================")
        print("[WiFiComm] Starting WiFi monitoring")
        print("[WiFiComm] Device IP: \(ip)")
        print("[WiFiComm] Ping interval: \(pingInterval)s")
        print("========================================")

        // Stop existing timer if any
        pingTimer?.invalidate()

        // Start ping timer
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            self?.performPing()
        }

        // Perform initial ping
        performPing()
    }

    func stopMonitoring() {
        print("[WiFiComm] Stopping WiFi monitoring")
        pingTimer?.invalidate()
        pingTimer = nil
        isConnected = false
        deviceIP = nil
        lastPingTime = nil
    }

    // MARK: - Ping Monitoring
    private func performPing() {
        guard let ip = deviceIP else {
            print("[WiFiComm] No IP address set")
            return
        }

        let url = URL(string: "http://\(ip):8080/ping")!

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.handlePingFailure(error: error)
                } else if let data = data {
                    self?.handlePingSuccess(data: data)
                } else {
                    self?.handlePingFailure(error: NSError(domain: "No data", code: -1))
                }
            }
        }

        task.resume()
    }

    private func handlePingSuccess(data: Data) {
        consecutiveFailures = 0
        lastPingTime = Date()

        // Parse ping response (optional)
        if let json = try? JSONDecoder().decode([String: AnyCodable].self, from: data) {
            if let status = json["status"]?.value as? String {
                print("[WiFiComm] Ping successful - Status: \(status)")
            }
        }

        // Update connection state
        if !isConnected {
            print("========================================")
            print("[WiFiComm] ✅ WiFi connection RESTORED")
            print("========================================")
            isConnected = true
            onConnectionRestored?()
        }

        connectionQuality = 100
    }

    private func handlePingFailure(error: Error) {
        consecutiveFailures += 1

        print("[WiFiComm] Ping failed (\(consecutiveFailures)/\(maxFailures)): \(error.localizedDescription)")

        // Calculate connection quality
        connectionQuality = max(0, 100 - (consecutiveFailures * 33))

        // Trigger connection lost after max failures
        if consecutiveFailures >= maxFailures && isConnected {
            print("========================================")
            print("[WiFiComm] ❌ WiFi connection LOST")
            print("[WiFiComm] Consecutive failures: \(consecutiveFailures)")
            print("========================================")

            isConnected = false
            onConnectionLost?()
        }
    }

    // MARK: - Sensor Data Fetching
    func fetchSensorData(completion: @escaping (Result<SensorDataResponse, Error>) -> Void) {
        guard let ip = deviceIP else {
            completion(.failure(NSError(domain: "No IP address", code: -1)))
            return
        }

        let url = URL(string: "http://\(ip):8080/data")!

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: -1)))
                return
            }

            do {
                let sensorData = try JSONDecoder().decode(SensorDataResponse.self, from: data)

                DispatchQueue.main.async {
                    self?.lastSensorData = sensorData
                    self?.onSensorDataReceived?(sensorData)
                }

                completion(.success(sensorData))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Send Command
    func sendCommand(_ command: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let ip = deviceIP else {
            completion(.failure(NSError(domain: "No IP address", code: -1)))
            return
        }

        let url = URL(string: "http://\(ip):8080/command")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let commandData = ["command": command]
        request.httpBody = try? JSONEncoder().encode(commandData)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(()))
        }.resume()
    }

    // MARK: - Utility
    func isMonitoring() -> Bool {
        return pingTimer != nil && deviceIP != nil
    }

    func getDeviceIP() -> String? {
        return deviceIP
    }
}

// MARK: - Helper for Any Codable
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        }
    }
}
