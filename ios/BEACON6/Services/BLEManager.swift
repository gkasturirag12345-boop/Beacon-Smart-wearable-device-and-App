//
//  BLEManager.swift
//  BEACON
//
//  Bluetooth Low Energy Manager for Arduino connectivity
//

import Foundation
import CoreBluetooth
import Combine

class BLEManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var isConnected = false
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var connectedDevice: CBPeripheral?
    @Published var connectionStatus = "Disconnected"

    // MARK: - BLE Properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var heartRateCharacteristic: CBCharacteristic?
    private var fallDetectionCharacteristic: CBCharacteristic?
    private var sosAlertCharacteristic: CBCharacteristic?
    private var controlCharacteristic: CBCharacteristic?  // NEW: Control command characteristic
    private var audioCharacteristic: CBCharacteristic?  // Audio streaming from ESP32 mic

    // MARK: - UUIDs (match firmware/Code_that_works2 BLEManager / Config.h)
    // Service UUID - Main health monitoring service
    private let serviceUUID = CBUUID(string: "12345678-9012-3456-7890-1234567890AB")

    // Characteristic UUIDs
    private let heartRateCharacteristicUUID = CBUUID(string: "12345678-9012-3456-7890-1234567890AC") // Heart Rate (Notify/Read)
    private let alertCharacteristicUUID = CBUUID(string: "12345678-9012-3456-7890-1234567890AD") // AlertStatus (Notify/Read)
    private let controlCharacteristicUUID = CBUUID(string: "12345678-9012-3456-7890-1234567890AE") // ControlCommand (Write)
    private let audioCharacteristicUUID = CBUUID(string: "12345678-9012-3456-7890-1234567890AF") // Audio Stream (Notify/Read)

    // MARK: - Callbacks
    var onHeartRateReceived: ((Double) -> Void)?
    var onFallDetected: ((Double, String?) -> Void)?
    var onSleepDataReceived: ((Double, Double) -> Void)?
    var onSOSAlertReceived: (() -> Void)?
    var onFalseAlarmReceived: (() -> Void)?  // NEW: False alarm callback (double button press)
    var onWearStatusReceived: ((WearStatus) -> Void)?  // NEW: Wear status callback
    var onAudioDataReceived: ((Data) -> Void)?  // NEW: Audio stream from ESP32 microphone

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            connectionStatus = "Bluetooth is not available"
            return
        }

        discoveredDevices.removeAll()
        isScanning = true
        connectionStatus = "Scanning..."

        // Scan for ALL devices (nil = no service filter)
        // Options: allow duplicates to refresh RSSI values
        let options: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ]
        centralManager.scanForPeripherals(withServices: nil, options: options)

        print("[BLE] Started scanning for all Bluetooth devices...")

        // Auto-stop scanning after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        if !isConnected {
            connectionStatus = "Scan stopped"
        }
    }

    func connect(to peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self

        // Connection options for stability and throughput
        let options: [String: Any] = [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnNotificationKey: true
        ]

        centralManager.connect(peripheral, options: options)
        connectionStatus = "Connecting..."

        // Set connection timeout (15 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self, !self.isConnected, self.peripheral == peripheral else { return }
            self.centralManager.cancelPeripheralConnection(peripheral)
            self.connectionStatus = "Connection timeout"
        }
    }

    /// Request maximum MTU for better throughput
    private func requestMaximumMTU() {
        guard let peripheral = peripheral else { return }

        // Request maximum MTU (247 bytes for BLE 4.2+)
        peripheral.readRSSI()  // Triggers MTU negotiation
        peripheral.maximumWriteValueLength(for: .withResponse)

        print("[BLE] 📡 Requesting maximum MTU (247 bytes)")
    }

    func disconnect() {
        guard let peripheral = peripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        connectionStatus = "Disconnecting..."
    }

    // MARK: - Control Commands

    /// Send control command to ESP32-C3 device
    func sendControlCommand(_ command: String) {
        guard let characteristic = controlCharacteristic,
              let peripheral = peripheral else {
            print("[BLE] Control characteristic not available")
            return
        }

        guard let data = command.data(using: .utf8) else {
            print("[BLE] Failed to encode command: \(command)")
            return
        }

        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("[BLE TX] Sent control command: \(command)")
    }

    /// Send SOS keyword detection alert to ESP32-C3
    func sendSOSKeywordDetected(confidence: Float) {
        let command = "SOS_KEYWORD_\(String(format: "%.2f", confidence))"
        sendControlCommand(command)
        print("[BLE TX] 🚨 SOS keyword detected - sent to device (confidence: \(confidence))")
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connectionStatus = "Bluetooth ready"
        case .poweredOff:
            connectionStatus = "Bluetooth is off"
        case .unauthorized:
            connectionStatus = "Bluetooth not authorized"
        case .unsupported:
            connectionStatus = "Bluetooth not supported"
        default:
            connectionStatus = "Bluetooth unavailable"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Don't add devices with very weak signal (optional filter)
        guard RSSI.intValue > -80 else { return }

        let deviceName = peripheral.name ?? "Unknown Device"

        // **FILTER: Only show BEACON, ESP32, or Nano33IoT devices**
        // Accept devices with names containing "BEACON", "ESP32", or "NANO33IOT"
        let nameUpper = deviceName.uppercased()
        guard nameUpper.contains("BEACON") || nameUpper.contains("ESP32") || nameUpper.contains("NANO33IOT") else {
            // Silently ignore non-matching devices
            return
        }

        // Log advertisement data for debugging
        print("[BLE] Discovered BEACON device: \(deviceName)")
        print("     UUID: \(peripheral.identifier.uuidString)")
        print("     RSSI: \(RSSI) dBm")
        print("     Advertisement Data: \(advertisementData)")

        // Add device if not already in list
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            DispatchQueue.main.async {
                self.discoveredDevices.append(peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[BLE] Successfully connected to \(peripheral.name ?? "Device")")

        isConnected = true
        connectedDevice = peripheral
        connectionStatus = "Connected to \(peripheral.name ?? "Device")"

        peripheral.delegate = self

        // Request maximum MTU for higher throughput
        requestMaximumMTU()

        // Discover all services to be more flexible with Arduino UUIDs
        peripheral.discoverServices(nil)

        stopScanning()

        print("[BLE] 🔧 Connection optimization: Requesting max MTU (247 bytes)")
        print("[BLE] 🔧 Expecting ADPCM-compressed audio from ESP32 (4:1 ratio)")
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectionStatus = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectedDevice = nil
        heartRateCharacteristic = nil
        fallDetectionCharacteristic = nil
        sosAlertCharacteristic = nil
        controlCharacteristic = nil
        audioCharacteristic = nil

        if let error = error {
            print("[BLE] Unexpected disconnection: \(error.localizedDescription)")
            connectionStatus = "Disconnected unexpectedly"

            // Auto-reconnect attempt for unexpected disconnections
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self = self else { return }
                print("[BLE] Attempting to reconnect...")
                self.connect(to: peripheral)
            }
        } else {
            print("[BLE] Disconnected normally")
            connectionStatus = "Disconnected"
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("[BLE] Error discovering services: \(error.localizedDescription)")
            connectionStatus = "Service discovery failed"
            return
        }

        guard let services = peripheral.services, !services.isEmpty else {
            print("[BLE] No services found")
            connectionStatus = "No services available"
            return
        }

        print("[BLE] Discovered \(services.count) service(s)")
        for service in services {
            print("[BLE] Service UUID: \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("[BLE] Error discovering characteristics: \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics, !characteristics.isEmpty else {
            print("[BLE] No characteristics found for service \(service.uuid)")
            return
        }

        print("[BLE] Discovered \(characteristics.count) characteristic(s) for service \(service.uuid)")
        print("========================================")
        print("SERVICE UUID: \(service.uuid)")
        print("========================================")
        for characteristic in characteristics {
            print("  CHARACTERISTIC UUID: \(characteristic.uuid)")
            print("  Properties: \(characteristic.properties.rawValue)")
            var propString = "  Supports: "
            if characteristic.properties.contains(.read) { propString += "READ " }
            if characteristic.properties.contains(.write) { propString += "WRITE " }
            if characteristic.properties.contains(.notify) { propString += "NOTIFY " }
            if characteristic.properties.contains(.indicate) { propString += "INDICATE " }
            print(propString)
            print("----------------------------------------")

            // Subscribe to heart rate notifications
            if characteristic.uuid == heartRateCharacteristicUUID {
                heartRateCharacteristic = characteristic
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("[BLE] Subscribed to heart rate notifications")
                    connectionStatus = "Receiving data..."
                }
            }

            // Subscribe to alert notifications (handles all alert types)
            if characteristic.uuid == alertCharacteristicUUID {
                fallDetectionCharacteristic = characteristic  // Reuse for compatibility
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("[BLE] Subscribed to alert notifications (FALL, HEART_STOP, MANUAL, FALSE_ALARM, WEAR)")
                }
            }

            // Store control characteristic reference (for writing commands)
            if characteristic.uuid == controlCharacteristicUUID {
                controlCharacteristic = characteristic
                if characteristic.properties.contains(.write) {
                    print("[BLE] Control command characteristic ready (Write enabled)")
                }
            }

            // Subscribe to audio stream notifications (ESP32 I2S microphone)
            if characteristic.uuid == audioCharacteristicUUID {
                audioCharacteristic = characteristic
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("[BLE] 🎤 Subscribed to audio stream from ESP32 microphone (16kHz, 16-bit)")
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[BLE] ❌ Error changing notification state: \(error.localizedDescription)")
            return
        }

        // Enhanced diagnostic logging for notification state changes
        var charType = "UNKNOWN"
        if characteristic.uuid == heartRateCharacteristicUUID {
            charType = "HEART_RATE (AC)"
        } else if characteristic.uuid == alertCharacteristicUUID {
            charType = "ALERT (AD)"
        } else if characteristic.uuid == audioCharacteristicUUID {
            charType = "AUDIO (AF)"
        }

        if characteristic.isNotifying {
            print("[BLE] ✅ Notifications ENABLED for \(charType)")
            print("[BLE]    UUID: \(characteristic.uuid)")
            print("[BLE]    Status: Ready to receive data")
        } else {
            print("[BLE] ⚠️ Notifications DISABLED for \(charType)")
            print("[BLE]    UUID: \(characteristic.uuid)")
        }

        // After all notifications are set, print subscription summary
        printSubscriptionStatus()
    }

    /// Print diagnostic summary of all characteristic subscriptions
    private func printSubscriptionStatus() {
        print("========================================")
        print("[BLE] 📊 Subscription Status Summary")
        print("========================================")

        if let hr = heartRateCharacteristic {
            print("  Heart Rate (AC): \(hr.isNotifying ? "✅ SUBSCRIBED" : "❌ NOT SUBSCRIBED")")
        } else {
            print("  Heart Rate (AC): ❌ CHARACTERISTIC NOT FOUND")
        }

        if let alert = fallDetectionCharacteristic {
            print("  Alert (AD):      \(alert.isNotifying ? "✅ SUBSCRIBED" : "❌ NOT SUBSCRIBED")")
        } else {
            print("  Alert (AD):      ❌ CHARACTERISTIC NOT FOUND")
        }

        if let audio = audioCharacteristic {
            print("  Audio (AF):      \(audio.isNotifying ? "✅ SUBSCRIBED" : "❌ NOT SUBSCRIBED")")
        } else {
            print("  Audio (AF):      ❌ CHARACTERISTIC NOT FOUND")
        }

        print("========================================")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[BLE] Error reading characteristic value: \(error.localizedDescription)")
            return
        }

        guard let data = characteristic.value else {
            print("[BLE] No data received for characteristic \(characteristic.uuid)")
            return
        }

        // Enhanced diagnostic logging with characteristic type identification
        var charType = "UNKNOWN"
        if characteristic.uuid == heartRateCharacteristicUUID {
            charType = "HEART_RATE (AC)"
        } else if characteristic.uuid == alertCharacteristicUUID {
            charType = "ALERT (AD)"
        } else if characteristic.uuid == audioCharacteristicUUID {
            charType = "AUDIO (AF)"
        } else if characteristic.uuid == controlCharacteristicUUID {
            charType = "CONTROL (AE)"
        }

        print("[BLE RX] 📥 Received from \(charType)")
        print("[BLE RX] UUID: \(characteristic.uuid)")
        print("[BLE RX] Size: \(data.count) bytes")
        print("[BLE RX] Hex: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")

        // Parse heart rate data
        if characteristic.uuid == heartRateCharacteristicUUID {
            print("[BLE RX] 🔍 Processing HEART RATE characteristic...")
            let bpm = parseHeartRate(from: data)
            // Validate heart rate range (0-200 BPM - allow 0 for heart stop)
            if bpm >= 0 && bpm <= 200 {
                print("[BLE RX] ✅ Heart Rate: \(bpm) BPM - VALID")
                onHeartRateReceived?(bpm)
            } else {
                print("[BLE RX] ❌ Invalid heart rate value: \(bpm) BPM - discarded")
            }
        }

        // Parse alert data (text strings from firmware)
        if characteristic.uuid == alertCharacteristicUUID {
            print("[BLE RX] 🔍 Processing ALERT characteristic...")
            parseAlertString(from: data)
        }

        // Handle audio stream data (ESP32 I2S microphone)
        if characteristic.uuid == audioCharacteristicUUID {
            print("[BLE RX] 🎤 Audio data received: \(data.count) bytes")
            onAudioDataReceived?(data)
        }
    }

    // MARK: - Data Parsing
    private func parseHeartRate(from data: Data) -> Double {
        // Handle both firmware's simple format and standard BLE format

        // Simple single-byte format (firmware sends just the BPM value)
        if data.count == 1 {
            let heartRate = UInt8(data[0])
            print("[BLE] Parsed heart rate (simple format): \(heartRate) BPM")
            return Double(heartRate)
        }

        // Standard BLE Heart Rate Measurement format (Bluetooth SIG specification)
        guard data.count >= 2 else {
            print("[BLE] Invalid heart rate data length: \(data.count)")
            return 0
        }

        var heartRate: UInt16 = 0
        let flags = data[0]

        // Bit 0: Heart Rate Value Format (0 = UINT8, 1 = UINT16)
        if (flags & 0x01) == 0 {
            // 8-bit heart rate value
            heartRate = UInt16(data[1])
        } else {
            // 16-bit heart rate value
            guard data.count >= 3 else {
                print("[BLE] Invalid 16-bit heart rate data length")
                return 0
            }
            // Little-endian format
            heartRate = UInt16(data[1]) | (UInt16(data[2]) << 8)
        }

        print("[BLE] Parsed heart rate (standard format): \(heartRate) BPM")
        return Double(heartRate)
    }

    private func parseFallDetection(from data: Data) -> Double {
        // Custom format: 4-byte float for impact magnitude (in G units)
        guard data.count >= 4 else {
            print("[BLE] Invalid fall detection data length: \(data.count)")
            return 0
        }

        // Parse as little-endian float
        let impact = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Float in
            guard let baseAddress = ptr.baseAddress else { return 0 }
            return baseAddress.load(as: Float.self)
        }

        // Check for NaN or infinite values
        guard impact.isFinite else {
            print("[BLE] Invalid fall detection value: \(impact)")
            return 0
        }

        return Double(impact)
    }

    private func parseAlertString(from data: Data) {
        // Parse text string alerts from firmware
        guard let alertString = String(data: data, encoding: .utf8) else {
            print("[BLE] Failed to decode alert string")
            return
        }

        print("[BLE RX] 🚨 Alert String: \"\(alertString)\"")

        // Handle different alert types
        switch alertString {
        case "FALL_DETECTED":
            print("[BLE RX] ✅ FALL DETECTED!")
            onFallDetected?(2.5, nil)  // Trigger with default magnitude

        case "HEART_STOP":
            print("[BLE RX] ✅ HEART STOP ALERT!")
            onHeartRateReceived?(0)  // Trigger with 0 BPM

        case "MANUAL_ALERT":
            print("[BLE RX] ✅ MANUAL ALERT (Single Button Press)")
            onSOSAlertReceived?()  // Trigger manual alert notification

        case "FALSE_ALARM":
            print("[BLE RX] ✅ FALSE ALARM (Double Button Press)")
            onFalseAlarmReceived?()  // Trigger false alarm notification

        case "DEVICE_WORN":
            print("[BLE RX] ✅ Device worn status: WORN")
            onWearStatusReceived?(.worn)

        case "DEVICE_NOT_WORN":
            print("[BLE RX] ✅ Device worn status: NOT WORN")
            onWearStatusReceived?(.notWorn)

        default:
            print("[BLE RX] ⚠️ Unknown alert type: \(alertString)")
        }
    }
}
