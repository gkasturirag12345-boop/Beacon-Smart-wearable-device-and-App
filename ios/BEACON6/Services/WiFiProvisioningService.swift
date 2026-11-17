//
//  WiFiProvisioningService.swift
//  BEACON
//
//  WiFi Provisioning Service for ESP32-C3
//  Sends WiFi credentials to device via BLE for network setup
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - WiFi Network Model
struct WiFiNetwork: Identifiable, Codable {
    let id = UUID()
    let ssid: String
    let rssi: Int
    let secure: Bool

    enum CodingKeys: String, CodingKey {
        case ssid, rssi, secure
    }
}

class WiFiProvisioningService: ObservableObject {
    static let shared = WiFiProvisioningService()

    // MARK: - Published Properties
    @Published var provisioningStatus: ProvisioningStatus = .idle
    @Published var deviceIPAddress: String? = nil
    @Published var wifiConnectionStatus: String = "Not configured"
    @Published var bleCharacteristicsReady: Bool = false  // Track BLE readiness
    @Published var isScanning: Bool = false  // Network scanning state
    @Published var availableNetworks: [WiFiNetwork] = []  // Discovered networks

    // MARK: - WiFi Provisioning UUIDs (Match ESP32-C3 wifi_manager.h)
    private let wifiServiceUUID = CBUUID(string: "87654321-9012-3456-7890-ABCDEF123456")
    private let wifiSSIDCharUUID = CBUUID(string: "87654321-9012-3456-7890-ABCDEF123457")
    private let wifiPasswordCharUUID = CBUUID(string: "87654321-9012-3456-7890-ABCDEF123458")
    private let wifiIPCharUUID = CBUUID(string: "87654321-9012-3456-7890-ABCDEF123459")
    private let wifiStatusCharUUID = CBUUID(string: "87654321-9012-3456-7890-ABCDEF12345A")
    private let controlCharUUID = CBUUID(string: "12345678-9012-3456-7890-1234567890AE")  // Control commands

    // MARK: - Private Properties
    private var peripheral: CBPeripheral?
    private var wifiSSIDCharacteristic: CBCharacteristic?
    private var wifiPasswordCharacteristic: CBCharacteristic?
    private var wifiIPCharacteristic: CBCharacteristic?
    private var wifiStatusCharacteristic: CBCharacteristic?
    private var controlCharacteristic: CBCharacteristic?  // For sending commands like SCAN_WIFI

    // Timeout and retry logic
    private var provisioningTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 2
    private let provisioningTimeout: TimeInterval = 25.0

    private init() {
        print("[WiFiProvisioning] Service initialized")
    }

    // MARK: - Provisioning Status
    enum ProvisioningStatus {
        case idle
        case sendingCredentials
        case waitingForConnection
        case connected
        case failed(String)
    }

    // MARK: - Setup
    func setupWithPeripheral(_ peripheral: CBPeripheral, characteristics: [CBCharacteristic]) {
        self.peripheral = peripheral

        print("========================================")
        print("[WiFiProvisioning] Setting up with \(characteristics.count) characteristics")
        print("========================================")

        for characteristic in characteristics {
            print("[WiFiProvisioning] Found UUID: \(characteristic.uuid)")

            switch characteristic.uuid {
            case wifiSSIDCharUUID:
                wifiSSIDCharacteristic = characteristic
                print("[WiFiProvisioning] ✅ SSID characteristic")

            case wifiPasswordCharUUID:
                wifiPasswordCharacteristic = characteristic
                print("[WiFiProvisioning] ✅ Password characteristic")

            case wifiIPCharUUID:
                wifiIPCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("[WiFiProvisioning] ✅ IP characteristic (subscribed)")

            case wifiStatusCharUUID:
                wifiStatusCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("[WiFiProvisioning] ✅ Status characteristic (subscribed)")

            case controlCharUUID:
                controlCharacteristic = characteristic
                print("[WiFiProvisioning] ✅ Control characteristic (for SCAN_WIFI)")

            default:
                print("[WiFiProvisioning] ⚠️  Unknown characteristic: \(characteristic.uuid)")
            }
        }

        print("========================================")
        print("[WiFiProvisioning] Setup summary:")
        print("[WiFiProvisioning]   SSID char: \(wifiSSIDCharacteristic != nil ? "✅" : "❌")")
        print("[WiFiProvisioning]   Password char: \(wifiPasswordCharacteristic != nil ? "✅" : "❌")")
        print("[WiFiProvisioning]   IP char: \(wifiIPCharacteristic != nil ? "✅" : "❌")")
        print("[WiFiProvisioning]   Status char: \(wifiStatusCharacteristic != nil ? "✅" : "❌")")
        print("[WiFiProvisioning]   Control char: \(controlCharacteristic != nil ? "✅" : "❌")")
        print("========================================")

        // Add delay to ensure BLE subscriptions are fully active
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.bleCharacteristicsReady = true
            print("========================================")
            print("[WiFiProvisioning] ✅ BLE characteristics READY")
            print("[WiFiProvisioning] Safe to send WiFi credentials")
            print("========================================")
        }
    }

    // MARK: - Send WiFi Credentials
    func provisionWiFi(ssid: String, password: String) {
        guard let peripheral = peripheral else {
            print("[WiFiProvisioning] ERROR: No peripheral connected")
            provisioningStatus = .failed("No device connected")
            return
        }

        guard let ssidChar = wifiSSIDCharacteristic,
              let passwordChar = wifiPasswordCharacteristic else {
            print("[WiFiProvisioning] ERROR: WiFi characteristics not found")
            provisioningStatus = .failed("WiFi service not available")
            return
        }

        // Check if BLE characteristics are ready
        guard bleCharacteristicsReady else {
            print("========================================")
            print("[WiFiProvisioning] ⚠️  BLE not ready yet")
            print("[WiFiProvisioning] Waiting for subscription setup...")
            print("========================================")

            provisioningStatus = .failed("BLE subscriptions not ready. Please wait a moment and try again.")
            return
        }

        // Cancel any existing timer
        provisioningTimer?.invalidate()
        retryCount = 0

        print("========================================")
        print("[WiFiProvisioning] 📤 Sending WiFi credentials")
        print("[WiFiProvisioning]   SSID: \(ssid)")
        print("[WiFiProvisioning]   Password: ********")
        print("[WiFiProvisioning]   Retry: \(retryCount)/\(maxRetries)")
        print("[WiFiProvisioning]   BLE Ready: ✅")
        print("========================================")

        provisioningStatus = .sendingCredentials

        // CRITICAL FIX: Wait 1 second to ensure BLE subscriptions are active
        // This prevents race condition where status is sent before app subscribes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            print("[WiFiProvisioning] ⏱️  BLE subscriptions ready, sending credentials...")

            // Send SSID
            if let ssidData = ssid.data(using: .utf8) {
                peripheral.writeValue(ssidData, for: ssidChar, type: .withResponse)
                print("[WiFiProvisioning] ✅ Step 1/2: SSID sent")
            }

            // Wait a moment then send password
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                if let passwordData = password.data(using: .utf8) {
                    peripheral.writeValue(passwordData, for: passwordChar, type: .withResponse)
                    print("[WiFiProvisioning] ✅ Step 2/2: Password sent")
                    print("[WiFiProvisioning] ⏳ Waiting for device to connect...")
                    self.provisioningStatus = .waitingForConnection
                }

                // Start timeout timer
                self.startProvisioningTimeout(ssid: ssid, password: password)
            }
        }

        // Store credentials locally for future use
        saveWiFiCredentials(ssid: ssid, password: password)
    }

    // MARK: - Timeout and Retry
    private func startProvisioningTimeout(ssid: String, password: String) {
        provisioningTimer?.invalidate()

        provisioningTimer = Timer.scheduledTimer(withTimeInterval: provisioningTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Check if we're still waiting
            if case .waitingForConnection = self.provisioningStatus {
                print("========================================")
                print("[WiFiProvisioning] ⚠️  Timeout: No response after \(Int(self.provisioningTimeout))s")
                print("========================================")

                if self.retryCount < self.maxRetries {
                    self.retryCount += 1
                    print("[WiFiProvisioning] 🔄 Retrying... Attempt \(self.retryCount)/\(self.maxRetries)")
                    self.provisionWiFi(ssid: ssid, password: password)
                } else {
                    print("[WiFiProvisioning] ❌ Max retries reached. Provisioning failed.")
                    self.provisioningStatus = .failed("Device did not respond. Check if device is powered on and within range.")
                }
            }
        }
    }

    private func cancelProvisioningTimeout() {
        provisioningTimer?.invalidate()
        provisioningTimer = nil
    }

    // MARK: - Handle Notifications
    func handleWiFiIPUpdate(_ data: Data) {
        if let ipString = String(data: data, encoding: .utf8) {
            print("========================================")
            print("[WiFiProvisioning] 📍 Device IP received: \(ipString)")
            print("========================================")

            // Cancel timeout - we got a response!
            cancelProvisioningTimeout()

            DispatchQueue.main.async {
                self.deviceIPAddress = ipString
                self.provisioningStatus = .connected
                self.retryCount = 0
            }

            // Save IP address for WiFi communication
            UserDefaults.standard.set(ipString, forKey: "deviceIPAddress")
        }
    }

    func handleWiFiStatusUpdate(_ data: Data) {
        if let statusString = String(data: data, encoding: .utf8) {
            print("========================================")
            print("[WiFiProvisioning] 📡 WiFi Status Update: \(statusString)")
            print("========================================")

            // Check if this is a scan result (JSON format)
            if statusString.starts(with: "{") && statusString.contains("networks") {
                print("[WiFiProvisioning] Detected scan results - routing to handleScanResults")
                handleScanResults(data)
                return
            }

            DispatchQueue.main.async {
                self.wifiConnectionStatus = statusString

                switch statusString {
                case "CONNECTED":
                    // IP address will come via separate notification
                    print("[WiFiProvisioning] ✅ WiFi connection successful!")
                    // Don't cancel timeout yet - wait for IP address
                    self.provisioningStatus = .connected

                case "CONNECTING":
                    print("[WiFiProvisioning] ⏳ Device is connecting to WiFi...")
                    self.provisioningStatus = .waitingForConnection

                case "FAILED":
                    print("[WiFiProvisioning] ❌ WiFi connection failed - wrong password or network unavailable")
                    self.cancelProvisioningTimeout()
                    self.provisioningStatus = .failed("WiFi connection failed. Check password and network availability.")

                case "DISCONNECTED":
                    print("[WiFiProvisioning] ⚠️  WiFi disconnected")
                    self.provisioningStatus = .idle
                    self.deviceIPAddress = nil

                default:
                    print("[WiFiProvisioning] ℹ️  Unknown status: \(statusString)")
                    break
                }
            }
        }
    }

    // MARK: - Credential Storage
    private func saveWiFiCredentials(ssid: String, password: String) {
        UserDefaults.standard.set(ssid, forKey: "wifiSSID")
        UserDefaults.standard.set(password, forKey: "wifiPassword")
        print("[WiFiProvisioning] Credentials saved to UserDefaults")
    }

    func getSavedCredentials() -> (ssid: String?, password: String?) {
        let ssid = UserDefaults.standard.string(forKey: "wifiSSID")
        let password = UserDefaults.standard.string(forKey: "wifiPassword")
        return (ssid, password)
    }

    func getSavedIPAddress() -> String? {
        return UserDefaults.standard.string(forKey: "deviceIPAddress")
    }

    func clearSavedCredentials() {
        UserDefaults.standard.removeObject(forKey: "wifiSSID")
        UserDefaults.standard.removeObject(forKey: "wifiPassword")
        UserDefaults.standard.removeObject(forKey: "deviceIPAddress")
        deviceIPAddress = nil
        provisioningStatus = .idle
        wifiConnectionStatus = "Not configured"
        print("[WiFiProvisioning] Credentials cleared")
    }

    // MARK: - Status Checks
    func isProvisioned() -> Bool {
        return deviceIPAddress != nil
    }

    func getProvisioningStatusString() -> String {
        switch provisioningStatus {
        case .idle:
            return "Not configured"
        case .sendingCredentials:
            return "Sending credentials..."
        case .waitingForConnection:
            return "Connecting to WiFi..."
        case .connected:
            return "Connected via WiFi"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    // MARK: - WiFi Network Scanning (BLE-based)

    /// Scan for available WiFi networks via ESP32-C3 device
    func scanForNetworks() {
        guard let peripheral = peripheral else {
            print("[WiFiProvisioning] ERROR: No peripheral connected")
            return
        }

        guard let controlChar = controlCharacteristic else {
            print("[WiFiProvisioning] ERROR: Control characteristic not found")
            return
        }

        print("========================================")
        print("[WiFiProvisioning] 📡 Sending SCAN_WIFI command to device")
        print("========================================")

        isScanning = true
        availableNetworks.removeAll()

        // Send SCAN_WIFI command to ESP32-C3
        if let data = "SCAN_WIFI".data(using: .utf8) {
            peripheral.writeValue(data, for: controlChar, type: .withResponse)
            print("[WiFiProvisioning] ✅ SCAN_WIFI command sent")
        }

        // Timeout after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            if self?.isScanning == true {
                print("[WiFiProvisioning] ⚠️  Network scan timeout")
                self?.isScanning = false
            }
        }
    }

    /// Handle network scan results from ESP32-C3
    func handleScanResults(_ data: Data) {
        print("========================================")
        print("[WiFiProvisioning] 📥 Received scan results")
        print("========================================")

        isScanning = false

        // Try to parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let networksArray = json["networks"] as? [[String: Any]] else {
            print("[WiFiProvisioning] ❌ Failed to parse scan results")

            // Try parsing as simple string list (fallback)
            if let resultString = String(data: data, encoding: .utf8) {
                print("[WiFiProvisioning] Raw data: \(resultString)")
            }
            return
        }

        // Parse network objects
        var networks: [WiFiNetwork] = []
        for dict in networksArray {
            guard let ssid = dict["ssid"] as? String,
                  let rssi = dict["rssi"] as? Int,
                  let secure = dict["secure"] as? Bool else {
                continue
            }
            networks.append(WiFiNetwork(ssid: ssid, rssi: rssi, secure: secure))
        }

        DispatchQueue.main.async {
            self.availableNetworks = networks.sorted { $0.rssi > $1.rssi }  // Sort by signal strength
            print("[WiFiProvisioning] ✅ Found \(networks.count) networks")
            for network in self.availableNetworks {
                print("[WiFiProvisioning]   • \(network.ssid) (\(network.rssi) dBm) \(network.secure ? "🔒" : "")")
            }
        }
    }
}
