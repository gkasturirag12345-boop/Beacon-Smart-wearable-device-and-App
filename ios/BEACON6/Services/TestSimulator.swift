//
//  TestSimulator.swift
//  BEACON
//
//  Native iOS Test Mode Simulator
//  Generates simulated sensor data when no real device is connected
//

import Foundation
import Combine

/// Test mode simulator for development without hardware
class TestSimulator: ObservableObject {
    static let shared = TestSimulator()

    // MARK: - Published Properties
    @Published var isRunning: Bool = false
    @Published var currentWearStatus: WearStatus = .worn
    @Published var baselineHeartRate: Double = 75

    // MARK: - Configuration
    private let dataInterval: TimeInterval = 2.0 // 2 seconds
    private let wearToggleInterval: TimeInterval = 10.0 // 10 seconds
    private let heartRateMin: Double = 60
    private let heartRateMax: Double = 120
    private let heartRateVariance: Double = 5

    // MARK: - Private State
    private var dataTimer: Timer?
    private var wearToggleTimer: Timer?
    private let dataStore = DataStore.shared
    private let alertManager = AlertManager.shared

    private init() {
        print("[TestSimulator] Initialized")
    }

    deinit {
        stop()
    }

    // MARK: - Control

    /// Start test mode simulation
    func start() {
        guard !isRunning else {
            print("[TestSimulator] Already running")
            return
        }

        print("[TestSimulator] Starting simulation...")

        isRunning = true
        currentWearStatus = .worn
        baselineHeartRate = 75

        // Update device state in data store
        dataStore.setDeviceConnected(
            deviceId: "test-simulator",
            deviceName: "Test Simulator"
        )

        // Set initial wear status
        dataStore.updateWearStatus(currentWearStatus)

        // Start data generation timer
        dataTimer = Timer.scheduledTimer(
            withTimeInterval: dataInterval,
            repeats: true
        ) { [weak self] _ in
            self?.generateData()
        }

        // Start wear toggle timer
        wearToggleTimer = Timer.scheduledTimer(
            withTimeInterval: wearToggleInterval,
            repeats: true
        ) { [weak self] _ in
            self?.toggleWearStatus()
        }

        // Generate initial data immediately
        generateData()

        print("[TestSimulator] Simulation active")
    }

    /// Stop test mode simulation
    func stop() {
        guard isRunning else {
            print("[TestSimulator] Not running")
            return
        }

        print("[TestSimulator] Stopping simulation...")

        // Stop timers
        dataTimer?.invalidate()
        dataTimer = nil

        wearToggleTimer?.invalidate()
        wearToggleTimer = nil

        isRunning = false

        // Update device state
        dataStore.setDeviceDisconnected()

        print("[TestSimulator] Simulation stopped")
    }

    // MARK: - Data Generation

    /// Generate simulated sensor data
    private func generateData() {
        // Generate heart rate
        let heartRate = generateHeartRate()
        dataStore.updateHeartRate(heartRate)

        // Generate motion
        let motion = generateMotion()
        dataStore.updateMotion(motion)

        // Check for alerts
        alertManager.processHeartRate(heartRate, wearStatus: currentWearStatus)
        alertManager.processMotion(magnitude: motion.magnitude, wearStatus: currentWearStatus)

        // Log in debug mode
        #if DEBUG
        print("[TestSimulator] Generated: HR=\(Int(heartRate)) BPM, Motion=\(String(format: "%.3f", motion.magnitude))G, Wear=\(currentWearStatus.rawValue)")
        #endif
    }

    /// Generate realistic heart rate with natural variability
    private func generateHeartRate() -> Double {
        // Add small random variation to baseline
        let variation = Double.random(in: -heartRateVariance...heartRateVariance)
        var heartRate = baselineHeartRate + variation

        // Constrain to valid range
        heartRate = max(heartRateMin, min(heartRateMax, heartRate))

        // Occasionally simulate exercise (5% chance)
        if Double.random(in: 0...1) > 0.95 {
            baselineHeartRate = Double.random(in: 85...110)
            print("[TestSimulator] Simulating elevated heart rate: \(Int(baselineHeartRate)) BPM")
        }

        // Gradually return to resting rate
        if baselineHeartRate > 75 {
            baselineHeartRate -= 0.5
        } else if baselineHeartRate < 70 {
            baselineHeartRate += 0.5
        }

        // Occasionally simulate abnormal heart rates for alert testing (0.5% chance)
        if Double.random(in: 0...1) > 0.995 {
            let abnormal = Bool.random() ?
                Double.random(in: 120...140) : // High
                Double.random(in: 35...50)     // Low
            print("[TestSimulator] ⚠️ Simulating abnormal heart rate: \(Int(abnormal)) BPM")
            return abnormal
        }

        return round(heartRate)
    }

    /// Generate simulated motion/accelerometer data
    private func generateMotion() -> MotionData {
        // Normal motion: small random movements
        let x = Double.random(in: -0.1...0.1)
        let y = Double.random(in: -0.1...0.1)
        let z = Double.random(in: -0.1...0.1)

        // Occasionally simulate a fall (0.1% chance)
        if Double.random(in: 0...1) > 0.999 {
            let fallImpact = Double.random(in: 3.0...5.0)
            print("[TestSimulator] 🚨 Simulating FALL! Impact: \(String(format: "%.2f", fallImpact)) G")

            return MotionData(
                x: fallImpact * (Double.random(in: -0.5...0.5)),
                y: fallImpact * (Double.random(in: -0.5...0.5)),
                z: fallImpact * (Double.random(in: -0.5...0.5))
            )
        }

        return MotionData(x: x, y: y, z: z)
    }

    /// Toggle wear status for testing
    private func toggleWearStatus() {
        // Toggle between worn and not worn
        currentWearStatus = currentWearStatus == .worn ? .notWorn : .worn

        // Update data store
        dataStore.updateWearStatus(currentWearStatus)

        print("[TestSimulator] Wear status toggled: \(currentWearStatus.rawValue)")
    }

    // MARK: - Manual Triggers (for UI testing)

    /// Manually trigger high heart rate alert
    func triggerHighHeartRate() {
        print("[TestSimulator] ⚠️ Manually triggering high heart rate alert")
        baselineHeartRate = 135
        generateData()
    }

    /// Manually trigger low heart rate alert
    func triggerLowHeartRate() {
        print("[TestSimulator] ⚠️ Manually triggering low heart rate alert")
        baselineHeartRate = 35
        generateData()
    }

    /// Manually trigger fall detection alert
    func triggerFallDetection() {
        print("[TestSimulator] 🚨 Manually triggering fall detection alert")

        let fallMotion = MotionData(x: 2.0, y: 1.5, z: 3.5)
        dataStore.updateMotion(fallMotion)

        alertManager.processMotion(
            magnitude: fallMotion.magnitude,
            wearStatus: currentWearStatus
        )
    }

    /// Set specific wear status
    func setWearStatus(_ status: WearStatus) {
        currentWearStatus = status
        dataStore.updateWearStatus(status)
        print("[TestSimulator] Wear status set to: \(status.rawValue)")
    }

    // MARK: - Status

    /// Get current simulation status
    func getStatus() -> SimulatorStatus {
        return SimulatorStatus(
            running: isRunning,
            wearStatus: currentWearStatus,
            baselineHeartRate: baselineHeartRate
        )
    }
}

// MARK: - Status Model

struct SimulatorStatus {
    let running: Bool
    let wearStatus: WearStatus
    let baselineHeartRate: Double
}
