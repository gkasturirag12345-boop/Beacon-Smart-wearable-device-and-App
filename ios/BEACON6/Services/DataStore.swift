//
//  DataStore.swift
//  BEACON
//
//  Native iOS Data Storage
//  In-memory storage for health data with circular buffers
//

import Foundation
import Combine

/// Device connection state
struct DeviceState {
    var connected: Bool = false
    var deviceId: String? = nil
    var deviceName: String? = nil
    var lastConnected: Date? = nil
    var reconnectAttempts: Int = 0
}

/// Latest sensor readings
struct SensorData {
    var heartRate: Double? = nil
    var motion: MotionData? = nil
    var wearStatus: WearStatus = .unknown
    var timestamp: Date? = nil
}

/// Motion/Accelerometer data
struct MotionData {
    let x: Double
    let y: Double
    let z: Double
    let magnitude: Double

    init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.magnitude = sqrt(x*x + y*y + z*z)
    }
}

/// Data point for historical storage
struct DataPoint<T> {
    let value: T
    let timestamp: Date

    init(value: T, timestamp: Date = Date()) {
        self.value = value
        self.timestamp = timestamp
    }
}

/// Central data storage for health monitoring
class DataStore: ObservableObject {
    static let shared = DataStore()

    // MARK: - Published Properties
    @Published var deviceState = DeviceState()
    @Published var latestData = SensorData()

    // MARK: - Historical Data (Circular Buffers)
    private var heartRateHistory: [DataPoint<Double>] = []
    private var motionHistory: [DataPoint<MotionData>] = []
    private var wearStatusHistory: [DataPoint<WearStatus>] = []

    // MARK: - Configuration
    private let maxHistorySize = 1000
    private let cleanupInterval: TimeInterval = 3600 // 1 hour
    private var cleanupTimer: Timer?

    // MARK: - Statistics
    @Published var stats = Statistics()

    private init() {
        print("[DataStore] Initialized")
        startCleanupTimer()
    }

    deinit {
        cleanupTimer?.invalidate()
    }

    // MARK: - Device State Management

    func setDeviceConnected(deviceId: String, deviceName: String) {
        DispatchQueue.main.async { [weak self] in
            self?.deviceState.connected = true
            self?.deviceState.deviceId = deviceId
            self?.deviceState.deviceName = deviceName
            self?.deviceState.lastConnected = Date()
            self?.deviceState.reconnectAttempts = 0
        }
        print("[DataStore] Device connected: \(deviceName)")
    }

    func setDeviceDisconnected() {
        DispatchQueue.main.async { [weak self] in
            self?.deviceState.connected = false
            self?.deviceState.deviceId = nil
            self?.deviceState.deviceName = nil
        }
        print("[DataStore] Device disconnected")
    }

    func incrementReconnectAttempts() {
        DispatchQueue.main.async { [weak self] in
            self?.deviceState.reconnectAttempts += 1
        }
    }

    func resetReconnectAttempts() {
        DispatchQueue.main.async { [weak self] in
            self?.deviceState.reconnectAttempts = 0
        }
    }

    // MARK: - Sensor Data Management

    /// Update heart rate data
    func updateHeartRate(_ bpm: Double, timestamp: Date = Date()) {
        DispatchQueue.main.async { [weak self] in
            self?.latestData.heartRate = bpm
            self?.latestData.timestamp = timestamp
        }

        // Add to history
        addToHeartRateHistory(bpm, timestamp: timestamp)

        // Update stats
        DispatchQueue.main.async { [weak self] in
            self?.stats.totalDataPoints += 1
        }
    }

    /// Update motion data
    func updateMotion(_ motion: MotionData, timestamp: Date = Date()) {
        DispatchQueue.main.async { [weak self] in
            self?.latestData.motion = motion
            self?.latestData.timestamp = timestamp
        }

        // Add to history
        addToMotionHistory(motion, timestamp: timestamp)
    }

    /// Update wear status
    func updateWearStatus(_ status: WearStatus, timestamp: Date = Date()) {
        DispatchQueue.main.async { [weak self] in
            self?.latestData.wearStatus = status
            self?.latestData.timestamp = timestamp
        }

        // Add to history
        addToWearStatusHistory(status, timestamp: timestamp)
    }

    // MARK: - History Management

    private func addToHeartRateHistory(_ bpm: Double, timestamp: Date) {
        let dataPoint = DataPoint(value: bpm, timestamp: timestamp)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.heartRateHistory.append(dataPoint)

            // Trim to max size (circular buffer)
            if self.heartRateHistory.count > self.maxHistorySize {
                self.heartRateHistory.removeFirst()
            }
        }
    }

    private func addToMotionHistory(_ motion: MotionData, timestamp: Date) {
        let dataPoint = DataPoint(value: motion, timestamp: timestamp)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.motionHistory.append(dataPoint)

            // Trim to max size
            if self.motionHistory.count > self.maxHistorySize {
                self.motionHistory.removeFirst()
            }
        }
    }

    private func addToWearStatusHistory(_ status: WearStatus, timestamp: Date) {
        let dataPoint = DataPoint(value: status, timestamp: timestamp)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.wearStatusHistory.append(dataPoint)

            // Trim to max size
            if self.wearStatusHistory.count > self.maxHistorySize {
                self.wearStatusHistory.removeFirst()
            }
        }
    }

    /// Get heart rate history
    func getHeartRateHistory(limit: Int = 100) -> [DataPoint<Double>] {
        let count = min(limit, heartRateHistory.count)
        return Array(heartRateHistory.suffix(count))
    }

    /// Get motion history
    func getMotionHistory(limit: Int = 100) -> [DataPoint<MotionData>] {
        let count = min(limit, motionHistory.count)
        return Array(motionHistory.suffix(count))
    }

    /// Get wear status history
    func getWearStatusHistory(limit: Int = 100) -> [DataPoint<WearStatus>] {
        let count = min(limit, wearStatusHistory.count)
        return Array(wearStatusHistory.suffix(count))
    }

    /// Get all history
    func getAllHistory(limit: Int = 100) -> (
        heartRate: [DataPoint<Double>],
        motion: [DataPoint<MotionData>],
        wearStatus: [DataPoint<WearStatus>]
    ) {
        return (
            heartRate: getHeartRateHistory(limit: limit),
            motion: getMotionHistory(limit: limit),
            wearStatus: getWearStatusHistory(limit: limit)
        )
    }

    // MARK: - Statistics

    /// Get current statistics
    func getCurrentStats() -> Statistics {
        return Statistics(
            totalDataPoints: stats.totalDataPoints,
            heartRateDataPoints: heartRateHistory.count,
            motionDataPoints: motionHistory.count,
            wearStatusDataPoints: wearStatusHistory.count
        )
    }

    // MARK: - Data Cleanup

    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(
            withTimeInterval: cleanupInterval,
            repeats: true
        ) { [weak self] _ in
            self?.cleanup()
        }
    }

    /// Clean up old data (older than 24 hours)
    func cleanup() {
        let maxAge: TimeInterval = 24 * 60 * 60 // 24 hours
        let cutoffDate = Date().addingTimeInterval(-maxAge)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Remove old heart rate data
            self.heartRateHistory.removeAll { $0.timestamp < cutoffDate }

            // Remove old motion data
            self.motionHistory.removeAll { $0.timestamp < cutoffDate }

            // Remove old wear status data
            self.wearStatusHistory.removeAll { $0.timestamp < cutoffDate }

            print("[DataStore] Cleanup complete - removed data older than 24 hours")
        }
    }

    // MARK: - Reset

    /// Reset all data
    func reset() {
        DispatchQueue.main.async { [weak self] in
            self?.heartRateHistory.removeAll()
            self?.motionHistory.removeAll()
            self?.wearStatusHistory.removeAll()

            self?.latestData = SensorData()
            self?.stats = Statistics()

            print("[DataStore] All data reset")
        }
    }
}

// MARK: - Statistics Model

struct Statistics {
    var totalDataPoints: Int = 0
    var heartRateDataPoints: Int = 0
    var motionDataPoints: Int = 0
    var wearStatusDataPoints: Int = 0
}
