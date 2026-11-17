//
//  HealthMonitoringService.swift
//  BEACON
//
//  Main coordinator for health monitoring
//  Connects BLE, AlertManager, DataStore, and TestSimulator
//  Replaces computer backend with native iOS architecture
//

import Foundation
import Combine
import CoreBluetooth

#if canImport(UIKit)
import UIKit
#endif

/// Main health monitoring service - coordinates all components
class HealthMonitoringService: ObservableObject {
    static let shared = HealthMonitoringService()

    // MARK: - Services
    let bleManager: BLEManager // Public for BLEConnectionView
    private let dataStore = DataStore.shared
    let alertManager = AlertManager.shared // Public for DebugStatusView testing
    private let testSimulator = TestSimulator.shared
    private let notificationService = NotificationService.shared
    let keywordSpotter = KeywordSpotter() // Public for KeywordSpottingView

    // MARK: - Published State
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    @Published var isTestMode: Bool = false

    // MARK: - Current Data (for UI binding)
    @Published var currentHeartRate: Double?
    @Published var currentMotion: MotionData?
    @Published var currentWearStatus: WearStatus = .unknown
    @Published var activeAlerts: [HealthAlert] = []

    // MARK: - SOS Alert Banner (for immediate visual feedback)
    @Published var showSOSBanner: Bool = false
    @Published var sosAlertMessage: String = ""
    @Published var sosAlertConfidence: Float = 0.0
    @Published var sosDetectionTime: String = ""
    @Published var sosLatencyMs: Double = 0.0

    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
    private var keywordSpotterExternalEnabled = false
    private let adpcmDecoder = ADPCMDecoder()  // ADPCM decoder for ESP32 audio

    private init() {
        self.bleManager = BLEManager()
        setupBindings()
        setupBLECallbacks()
        setupKeywordSpotter()
        print("[HealthMonitoringService] Initialized")
    }

    /// Setup and auto-start KeywordSpotter for background SOS detection
    private func setupKeywordSpotter() {
        // Monitor keyword detection results
        keywordSpotter.$latestDetection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detection in
                guard let self = self else { return }

                // Debug logging
                if let detection = detection {
                    let receivedTime = Date()
                    let endToEndLatency = receivedTime.timeIntervalSince(detection.detectionTimestamp) * 1000

                    NSLog("[HealthMonitoringService] Detection received - keyword: %@, confidence: %.3f, isDetected: %@, latency: %.1fms",
                          detection.keyword, detection.confidence, detection.isDetected ? "YES" : "NO", endToEndLatency)
                }

                guard let detection = detection, detection.isDetected else {
                    NSLog("[HealthMonitoringService] Detection ignored (not SOS or below threshold)")
                    return
                }

                let alertTriggerTime = Date()
                let totalLatency = alertTriggerTime.timeIntervalSince(detection.detectionTimestamp) * 1000

                // SOS detected! Trigger alert
                NSLog("[HealthMonitoringService] 🚨 SOS DETECTED at %@ | Confidence: %.1f%% | Total latency: %.1fms",
                      detection.detectionTimeString, detection.confidence * 100, totalLatency)
                print("[HealthMonitoringService] 🚨 SOS KEYWORD DETECTED - Triggering alert")

                // Show in-app banner for immediate feedback
                self.sosAlertMessage = "SOS keyword detected with \(String(format: "%.1f", detection.confidence * 100))% confidence"
                self.sosAlertConfidence = detection.confidence
                self.sosDetectionTime = detection.detectionTimeString
                self.sosLatencyMs = totalLatency
                self.showSOSBanner = true

                // Haptic feedback - strong impact
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error) // Strong vibration
                #endif

                // Trigger notification and alert system with timing info
                self.alertManager.triggerSOSVoiceAlert(
                    confidence: Double(detection.confidence),
                    detectionTime: detection.detectionTimeString,
                    latencyMs: totalLatency
                )

                // Also notify via BLE if connected (send to ESP32)
                if self.bleManager.isConnected {
                    self.bleManager.sendSOSKeywordDetected(confidence: detection.confidence)
                }
            }
            .store(in: &cancellables)

        // Monitor model loading status and auto-start when ready
        keywordSpotter.$isModelLoaded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoaded in
                guard let self = self else { return }

                if isLoaded && !self.keywordSpotter.isListening {
                    print("[HealthMonitoringService] ✅ ML model loaded - starting SOS detection...")
                    self.keywordSpotter.startListening()
                }
            }
            .store(in: &cancellables)

        // Attempt immediate start (will succeed if model already loaded)
        print("[HealthMonitoringService] 🎤 Initializing SOS voice detection...")
        if keywordSpotter.isModelLoaded {
            print("[HealthMonitoringService] Model already loaded - starting immediately")
            keywordSpotter.startListening()
        } else {
            print("[HealthMonitoringService] Waiting for ML model to load...")
        }
    }

    // MARK: - Setup

    /// Setup data bindings between services and UI
    private func setupBindings() {
        // Monitor BLE connection status
        bleManager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self = self else { return }
                self.isConnected = connected && !(self.isTestMode)

                // Enable/disable external audio based on BLE connection
                if connected {
                    self.keywordSpotter.setExternalAudioEnabled(true)
                    print("[HealthMonitoringService] 🎤 External audio enabled (ESP32 mic)")
                } else {
                    self.keywordSpotter.setExternalAudioEnabled(false)
                    print("[HealthMonitoringService] 📱 Switched back to iPhone mic")
                }
            }
            .store(in: &cancellables)

        bleManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if self?.isTestMode == false {
                    self?.connectionStatus = status
                }
            }
            .store(in: &cancellables)

        // Monitor test simulator
        testSimulator.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] running in
                self?.isTestMode = running
                if running {
                    self?.isConnected = true
                    self?.connectionStatus = "Test Mode Active"
                }
            }
            .store(in: &cancellables)

        // Monitor data store for latest readings
        dataStore.$latestData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.currentHeartRate = data.heartRate
                self?.currentMotion = data.motion
                self?.currentWearStatus = data.wearStatus
            }
            .store(in: &cancellables)

        // Monitor alerts
        alertManager.$activeAlerts
            .receive(on: DispatchQueue.main)
            .assign(to: &$activeAlerts)
    }

    /// Setup BLE data callbacks
    private func setupBLECallbacks() {
        // Heart rate callback
        bleManager.onHeartRateReceived = { [weak self] bpm in
            guard let self = self else { return }

            print("[HealthMonitoringService] ❤️ Heart Rate: \(Int(bpm)) BPM")

            // Store data
            self.dataStore.updateHeartRate(bpm)

            // Check for alerts
            let wearStatus = self.dataStore.latestData.wearStatus
            self.alertManager.processHeartRate(bpm, wearStatus: wearStatus)
        }

        // Fall detection callback
        bleManager.onFallDetected = { [weak self] impact, location in
            guard let self = self else { return }

            print("[HealthMonitoringService] 🚨 Fall Detected: \(String(format: "%.2f", impact)) G")

            // Create motion data
            let motion = MotionData(x: 0, y: 0, z: impact)
            self.dataStore.updateMotion(motion)

            // Check for alerts
            let wearStatus = self.dataStore.latestData.wearStatus
            self.alertManager.processMotion(magnitude: impact, wearStatus: wearStatus)
        }

        // Sleep data callback
        bleManager.onSleepDataReceived = { [weak self] duration, quality in
            guard let self = self else { return }

            print("[HealthMonitoringService] 💤 Sleep Data: \(duration)h, Quality: \(quality)")

            // Could store sleep data here
            // For now, just log
        }

        // Manual alert callback (single button press)
        bleManager.onSOSAlertReceived = { [weak self] in
            print("[HealthMonitoringService] 🚨 MANUAL ALERT - Button Pressed!")

            self?.alertManager.triggerManualAlert(
                message: "Emergency button pressed on wearable device!",
                severity: .critical
            )
        }

        // False alarm callback (double button press)
        bleManager.onFalseAlarmReceived = { [weak self] in
            print("[HealthMonitoringService] ✅ FALSE ALARM - Double Button Press!")

            self?.alertManager.triggerFalseAlarm(
                message: "Alert cancelled by user (double button press)"
            )
        }

        // Wear status callback (NEW)
        bleManager.onWearStatusReceived = { [weak self] status in
            guard let self = self else { return }

            print("[HealthMonitoringService] 👕 Wear Status: \(status.rawValue)")

            // Update published property for UI
            DispatchQueue.main.async {
                self.currentWearStatus = status
            }

            // Update data store
            self.dataStore.updateWearStatus(status)
        }

        // Audio stream callback (ESP32 I2S microphone → CoreML SOS detection)
        bleManager.onAudioDataReceived = { [weak self] audioData in
            guard let self = self else { return }

            // Enable external audio mode if not already enabled
            if !self.keywordSpotterExternalEnabled {
                self.keywordSpotter.setExternalAudioEnabled(true)
                self.keywordSpotterExternalEnabled = true
                print("[HealthMonitoringService] 🎤 Enabled external audio from ESP32")
            }

            // Decode ADPCM compressed audio to PCM Int16 samples
            let pcmSamples = self.adpcmDecoder.decode(audioData)

            // Forward decoded audio to KeywordSpotter for SOS detection
            self.keywordSpotter.feedExternalAudio(pcmSamples)
        }
    }

    // MARK: - BLE Control

    /// Start scanning for BLE devices
    func startBLEScanning() {
        guard !isTestMode else {
            print("[HealthMonitoringService] Cannot scan in test mode")
            return
        }

        bleManager.startScanning()
    }

    /// Stop BLE scanning
    func stopBLEScanning() {
        bleManager.stopScanning()
    }

    /// Connect to specific BLE device
    func connect(to peripheral: CBPeripheral) {
        bleManager.connect(to: peripheral)
    }

    /// Disconnect from BLE device
    func disconnect() {
        bleManager.disconnect()
        alertManager.processDeviceDisconnection()
    }

    /// Get list of discovered devices
    func getDiscoveredDevices() -> [CBPeripheral] {
        return bleManager.discoveredDevices
    }

    // MARK: - Test Mode Control

    /// Enable test mode (disables BLE)
    func enableTestMode() {
        print("[HealthMonitoringService] Enabling test mode...")

        // Disconnect BLE if connected
        if bleManager.isConnected {
            bleManager.disconnect()
        }

        // Start test simulator
        testSimulator.start()
    }

    /// Disable test mode
    func disableTestMode() {
        print("[HealthMonitoringService] Disabling test mode...")
        testSimulator.stop()
    }

    /// Manually trigger test scenarios
    func triggerTestHeartRateHigh() {
        testSimulator.triggerHighHeartRate()
    }

    func triggerTestHeartRateLow() {
        testSimulator.triggerLowHeartRate()
    }

    func triggerTestFall() {
        testSimulator.triggerFallDetection()
    }

    // MARK: - Data Access

    /// Get current heart rate
    func getCurrentHeartRate() -> HeartRateData? {
        guard let bpm = dataStore.latestData.heartRate,
              let timestamp = dataStore.latestData.timestamp else {
            return nil
        }

        return HeartRateData(
            timestamp: timestamp,
            bpm: bpm,
            isAlert: bpm < 40 || bpm > 120
        )
    }

    /// Get heart rate history
    func getHeartRateHistory(limit: Int = 100) -> [HeartRateData] {
        let history = dataStore.getHeartRateHistory(limit: limit)

        return history.map { dataPoint in
            HeartRateData(
                timestamp: dataPoint.timestamp,
                bpm: dataPoint.value,
                isAlert: dataPoint.value < 40 || dataPoint.value > 120
            )
        }
    }

    /// Get latest sleep data (mock for now)
    func getLatestSleepData() -> SleepQualityData? {
        // This would be populated from actual sleep tracking
        // For now, return nil
        return nil
    }

    /// Get fall detection status
    func getFallDetectionStatus() -> FallDetectionEvent? {
        // Check if there are any unresolved fall alerts
        let fallAlerts = activeAlerts.filter { $0.type == .fallDetected && !$0.resolved }

        guard let latestFall = fallAlerts.first else {
            return nil
        }

        return FallDetectionEvent(
            timestamp: latestFall.timestamp,
            impactMagnitude: latestFall.value ?? 0,
            location: latestFall.metadata?["location"],
            resolved: latestFall.resolved
        )
    }

    // MARK: - Alert Management

    /// Get all alerts
    func getAlerts(unreadOnly: Bool = false) -> [HealthAlert] {
        if unreadOnly {
            return activeAlerts.filter { !$0.resolved }
        }
        return activeAlerts
    }

    /// Resolve an alert
    func resolveAlert(_ alertId: UUID) {
        alertManager.resolveAlert(alertId)
    }

    /// Delete an alert
    func deleteAlert(_ alertId: UUID) {
        alertManager.deleteAlert(alertId)
    }

    /// Clear resolved alerts
    func clearResolvedAlerts() {
        alertManager.clearResolvedAlerts()
    }

    /// Get alert statistics
    func getAlertStats() -> AlertStatistics {
        return alertManager.getAlertStats()
    }

    // MARK: - System Status

    /// Get comprehensive system status
    func getSystemStatus() -> SystemStatus {
        return SystemStatus(
            connected: isConnected,
            testMode: isTestMode,
            connectionStatus: connectionStatus,
            deviceName: dataStore.deviceState.deviceName,
            lastConnected: dataStore.deviceState.lastConnected,
            currentHeartRate: currentHeartRate,
            currentWearStatus: currentWearStatus,
            activeAlertsCount: activeAlerts.filter { !$0.resolved }.count,
            dataPoints: dataStore.getCurrentStats()
        )
    }

    // MARK: - Cleanup

    /// Reset all data
    func resetAllData() {
        dataStore.reset()
        alertManager.clearResolvedAlerts()
        print("[HealthMonitoringService] All data reset")
    }
}

// MARK: - System Status Model

struct SystemStatus {
    let connected: Bool
    let testMode: Bool
    let connectionStatus: String
    let deviceName: String?
    let lastConnected: Date?
    let currentHeartRate: Double?
    let currentWearStatus: WearStatus
    let activeAlertsCount: Int
    let dataPoints: Statistics
}
