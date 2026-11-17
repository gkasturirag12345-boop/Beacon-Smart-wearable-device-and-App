//
//  NetworkCoordinator.swift
//  BEACON
//
//  Network Coordinator - Manages automatic WiFi/BLE switching
//

import Foundation
import Combine

class NetworkCoordinator: ObservableObject {
    static let shared = NetworkCoordinator()

    // MARK: - Published Properties
    @Published var currentMode: ConnectionMode = .ble
    @Published var isTransitioning = false

    // MARK: - Private Properties
    private let wifiManager = WiFiCommunicationManager()
    private let provisioningService = WiFiProvisioningService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        print("[NetworkCoordinator] Initializing...")
        setupCallbacks()
    }

    // MARK: - Setup
    func initialize() {
        print("[NetworkCoordinator] Starting network coordination...")

        // Check if WiFi is provisioned
        if let ip = provisioningService.getSavedIPAddress() {
            print("[NetworkCoordinator] Found saved IP: \(ip)")
            attemptWiFiConnection(ip: ip)
        } else {
            print("[NetworkCoordinator] No saved WiFi credentials - using BLE mode")
            switchToBLEMode()
        }
    }

    private func setupCallbacks() {
        // WiFi connection lost callback
        wifiManager.onConnectionLost = { [weak self] in
            self?.handleWiFiLost()
        }

        // WiFi connection restored callback
        wifiManager.onConnectionRestored = { [weak self] in
            self?.handleWiFiRestored()
        }

        // Monitor provisioning status
        provisioningService.$deviceIPAddress
            .sink { [weak self] ip in
                if let ip = ip {
                    print("[NetworkCoordinator] New IP address received: \(ip)")
                    self?.attemptWiFiConnection(ip: ip)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Mode Switching
    private func attemptWiFiConnection(ip: String) {
        isTransitioning = true

        print("========================================")
        print("[NetworkCoordinator] Attempting WiFi connection")
        print("[NetworkCoordinator] IP: \(ip)")
        print("========================================")

        wifiManager.startMonitoring(ip: ip)

        // Give it a moment to establish connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isTransitioning = false

            if self?.wifiManager.isConnected == true {
                self?.switchToWiFiMode()
            } else {
                print("[NetworkCoordinator] WiFi connection failed - using BLE")
                self?.switchToBLEMode()
            }
        }
    }

    private func switchToWiFiMode() {
        guard currentMode != .wifi else { return }

        print("========================================")
        print("[NetworkCoordinator] 📡 Switching to WiFi mode")
        print("========================================")

        DispatchQueue.main.async {
            self.currentMode = .wifi
        }

        // Keep BLE active in background for fallback
    }

    private func switchToBLEMode() {
        guard currentMode != .ble else { return }

        print("========================================")
        print("[NetworkCoordinator] 📱 Switching to BLE mode")
        print("========================================")

        DispatchQueue.main.async {
            self.currentMode = .ble
        }
    }

    private func setOfflineMode() {
        print("========================================")
        print("[NetworkCoordinator] ⚠️ Entering OFFLINE mode")
        print("========================================")

        DispatchQueue.main.async {
            self.currentMode = .offline
        }
    }

    // MARK: - Event Handlers
    private func handleWiFiLost() {
        print("[NetworkCoordinator] WiFi connection lost - falling back to BLE")
        switchToBLEMode()

        // Continue trying to reconnect WiFi in background
        // WiFiCommunicationManager will keep pinging
    }

    private func handleWiFiRestored() {
        print("[NetworkCoordinator] WiFi connection restored")
        switchToWiFiMode()
    }

    // MARK: - Public Methods
    func forceWiFiMode(ip: String) {
        print("[NetworkCoordinator] Force switching to WiFi mode")
        attemptWiFiConnection(ip: ip)
    }

    func forceBLEMode() {
        print("[NetworkCoordinator] Force switching to BLE mode")
        wifiManager.stopMonitoring()
        switchToBLEMode()
    }

    func refreshConnection() {
        print("[NetworkCoordinator] Refreshing network connection...")

        if let ip = provisioningService.getSavedIPAddress() {
            attemptWiFiConnection(ip: ip)
        } else {
            switchToBLEMode()
        }
    }

    // MARK: - Data Access
    func fetchSensorData(completion: @escaping (Result<SensorDataResponse, Error>) -> Void) {
        if currentMode == .wifi && wifiManager.isConnected {
            wifiManager.fetchSensorData(completion: completion)
        } else {
            // BLE mode - data comes through BLE callbacks
            completion(.failure(NSError(domain: "Using BLE mode", code: 0)))
        }
    }

    func sendCommand(_ command: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if currentMode == .wifi && wifiManager.isConnected {
            wifiManager.sendCommand(command, completion: completion)
        } else {
            // BLE mode - use BLE control characteristic
            completion(.failure(NSError(domain: "BLE command not implemented", code: -1)))
        }
    }

    // MARK: - Status
    func getConnectionInfo() -> String {
        switch currentMode {
        case .wifi:
            if let ip = wifiManager.getDeviceIP() {
                return "WiFi: \(ip) (Quality: \(wifiManager.connectionQuality)%)"
            }
            return "WiFi (No IP)"

        case .ble:
            return "BLE Fallback Mode"

        case .offline:
            return "Offline - No Connection"
        }
    }
}
