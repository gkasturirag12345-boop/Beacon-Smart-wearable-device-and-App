/*
 * BLE Manager Implementation using NimBLE
 */

#include "BLEManager.h"

// ============================================================================
// Server Callbacks Implementation
// ============================================================================

void BLEManager::ServerCallbacks::onConnect(NimBLEServer* pServer) {
  bleManager->deviceConnected = true;
  bleManager->connectionParamsUpdated = false;

  // Enhanced connection logging
  Serial.println(F("========================================"));
  Serial.println(F("[BLE CALLBACK] onConnect() FIRED!"));
  Serial.println(F("========================================"));
  Serial.print(F("  Timestamp: "));
  Serial.print(millis());
  Serial.println(F(" ms"));
  Serial.print(F("  Connected clients: "));
  Serial.println(pServer->getConnectedCount());

  // Get peer device info
  std::vector<uint16_t> connIds = pServer->getPeerDevices();
  if (!connIds.empty()) {
    Serial.print(F("  Peer device ID: "));
    Serial.println(connIds[0]);
  }

  Serial.println(F("  deviceConnected flag: SET TO TRUE"));
  Serial.println(F("========================================"));

  // Request optimized connection parameters
  bleManager->requestConnectionUpdate();
  bleManager->requestMTUUpdate();
}

void BLEManager::ServerCallbacks::onDisconnect(NimBLEServer* pServer) {
  bleManager->deviceConnected = false;

  Serial.println(F("========================================"));
  Serial.println(F("[BLE CALLBACK] onDisconnect() FIRED!"));
  Serial.println(F("========================================"));
  Serial.print(F("  Timestamp: "));
  Serial.print(millis());
  Serial.println(F(" ms"));
  Serial.println(F("  deviceConnected flag: SET TO FALSE"));
  Serial.println(F("========================================"));
}

// ============================================================================
// Control Callbacks Implementation
// ============================================================================

void BLEManager::ControlCallbacks::onWrite(NimBLECharacteristic* pCharacteristic) {
  std::string value = pCharacteristic->getValue();

  if (value.length() > 0) {
    Serial.print(F("[BLE Control] Received command: "));
    Serial.println(value.c_str());

    if (value == "RESET_ALERT") {
      Serial.println(F("[BLE Control] Reset alert requested"));
      if (bleManager->resetAlertCallback) bleManager->resetAlertCallback();
    } else if (value == "TRIGGER_FALL") {
      Serial.println(F("[BLE Control] Manual fall trigger requested"));
      if (bleManager->triggerFallCallback) bleManager->triggerFallCallback();
    } else {
      Serial.print(F("[BLE Control] Unknown command: "));
      Serial.println(value.c_str());
    }
  }
}

// ============================================================================
// BLEManager Implementation
// ============================================================================

BLEManager::BLEManager()
  : pServer(nullptr),
    pHRCharacteristic(nullptr),
    pAlertCharacteristic(nullptr),
    pControlCharacteristic(nullptr),
    pAudioCharacteristic(nullptr),
    deviceConnected(false),
    oldDeviceConnected(false),
    currentMTU(23),  // Default BLE MTU
    connectionParamsUpdated(false),
    dataScheduler(nullptr),
    resetAlertCallback(nullptr),
    triggerFallCallback(nullptr) {
}

void BLEManager::begin() {
  Serial.println(F("Initializing NimBLE..."));

  // Use simpler name that iOS app can easily filter
  NimBLEDevice::init("ESP32-BEACON");

  // Set BLE power level to maximum for better range
  NimBLEDevice::setPower(ESP_PWR_LVL_P9);

  // Create BLE Server
  pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks(this));

  // Create BLE Service
  NimBLEService* pService = pServer->createService(SERVICE_UUID);

  // Heart rate characteristic
  pHRCharacteristic = pService->createCharacteristic(
    HR_CHAR_UUID,
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
  );

  // Alert characteristic
  pAlertCharacteristic = pService->createCharacteristic(
    ALERT_CHAR_UUID,
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
  );

  // Control command characteristic
  pControlCharacteristic = pService->createCharacteristic(
    CONTROL_CHAR_UUID,
    NIMBLE_PROPERTY::WRITE
  );
  pControlCharacteristic->setCallbacks(new ControlCallbacks(this));

  // Audio streaming characteristic (16kHz, 16-bit mono audio)
  pAudioCharacteristic = pService->createCharacteristic(
    AUDIO_CHAR_UUID,
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
  );

  // Start service
  pService->start();

  // Configure advertising for better discoverability
  NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);

  // Start advertising
  pAdvertising->start();

  Serial.println(F("================================="));
  Serial.println(F("NimBLE initialized"));
  Serial.println(F("Device name: ESP32-BEACON"));
  Serial.println(F("Service UUID: 12345678-9012-3456-7890-1234567890AB"));
  Serial.println(F("Advertising: ACTIVE (Health Monitoring Only)"));
  Serial.println(F("================================="));
}

void BLEManager::update() {
  // Handle BLE connection state changes
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);  // Give BLE stack time to prepare
    NimBLEDevice::startAdvertising();
    Serial.println(F("[BLE] Client disconnected - restarting advertising"));
    Serial.println(F("[BLE] Device name: ESP32-BEACON"));
    Serial.println(F("[BLE] Ready for iOS app to discover"));
    oldDeviceConnected = deviceConnected;
  }

  if (deviceConnected && !oldDeviceConnected) {
    Serial.println(F("[BLE] Client connected successfully"));
    oldDeviceConnected = deviceConnected;
  }

  // Safety check: ensure advertising when not connected
  static unsigned long lastBLECheck = 0;
  static unsigned long lastStatusPrint = 0;
  unsigned long currentTime = millis();

  // Print status every 30 seconds
  if (currentTime - lastStatusPrint > 30000) {
    lastStatusPrint = currentTime;
    if (!deviceConnected) {
      Serial.println(F("[BLE] Status: Waiting for connection..."));
      Serial.println(F("[BLE] Device name: ESP32-BEACON"));
      Serial.print(F("[BLE] Advertising: "));
      Serial.println(NimBLEDevice::getAdvertising()->isAdvertising() ? "YES" : "NO");
    }
  }

  if (currentTime - lastBLECheck > 5000) {
    lastBLECheck = currentTime;

    // Periodic connection status sync (fallback if callback doesn't fire)
    if (pServer) {
      uint16_t actualConnectedCount = pServer->getConnectedCount();
      bool actuallyConnected = (actualConnectedCount > 0);

      if (actuallyConnected && !deviceConnected) {
        // Connection exists but flag not set - sync it
        deviceConnected = true;
        Serial.println(F("========================================"));
        Serial.println(F("[BLE] Connection detected via periodic sync"));
        Serial.print(F("[BLE] Connected clients: "));
        Serial.println(actualConnectedCount);
        Serial.println(F("========================================"));
      } else if (!actuallyConnected && deviceConnected) {
        // Connection lost - update flag
        deviceConnected = false;
      }
    }

    if (!deviceConnected && !NimBLEDevice::getAdvertising()->isAdvertising()) {
      Serial.println(F("[BLE] WARNING: Advertising stopped unexpectedly - restarting!"));
      NimBLEDevice::startAdvertising();
    }
  }
}

void BLEManager::notifyHeartRate(uint8_t hr) {
  if (deviceConnected && pHRCharacteristic) {
    pHRCharacteristic->setValue(&hr, 1);
    pHRCharacteristic->notify();
  }
}

void BLEManager::notifyAlert(const char* alertType) {
  if (deviceConnected && pAlertCharacteristic) {
    pAlertCharacteristic->setValue(alertType);
    pAlertCharacteristic->notify();
  }
}

void BLEManager::notifyAudio(const uint8_t* audioData, size_t length) {
  if (deviceConnected && pAudioCharacteristic) {
    // BLE MTU is typically 244 bytes max (247 - 3 byte header)
    // Split into chunks if needed
    const size_t maxChunkSize = 244;

    if (length <= maxChunkSize) {
      pAudioCharacteristic->setValue(audioData, length);
      pAudioCharacteristic->notify();
    } else {
      // Send in chunks
      for (size_t offset = 0; offset < length; offset += maxChunkSize) {
        size_t chunkSize = (offset + maxChunkSize > length) ? (length - offset) : maxChunkSize;
        pAudioCharacteristic->setValue(audioData + offset, chunkSize);
        pAudioCharacteristic->notify();
        delay(10);  // Small delay between chunks to avoid overwhelming BLE stack
      }
    }
  }
}

void BLEManager::stopAdvertising() {
  Serial.println(F("[BLE] Stopping advertising..."));
  NimBLEDevice::getAdvertising()->stop();
  Serial.println(F("[BLE] Advertising stopped"));
}

void BLEManager::startAdvertising() {
  Serial.println(F("[BLE] Starting advertising..."));
  NimBLEDevice::startAdvertising();
  Serial.println(F("[BLE] Advertising active"));
}

bool BLEManager::isAdvertising() {
  return NimBLEDevice::getAdvertising()->isAdvertising();
}

void BLEManager::setResetAlertCallback(void (*callback)()) {
  resetAlertCallback = callback;
}

void BLEManager::setTriggerFallCallback(void (*callback)()) {
  triggerFallCallback = callback;
}

// ============================================================================
// DATA SCHEDULER INTEGRATION
// ============================================================================

void BLEManager::setDataScheduler(DataScheduler* scheduler) {
  dataScheduler = scheduler;
  Serial.println(F("[BLE] DataScheduler integrated"));
}

void BLEManager::processDataQueue() {
  // Diagnostic logging for debugging transmission issues
  static uint32_t lastDiagnosticLog = 0;
  uint32_t currentTime = millis();

  if (!dataScheduler) {
    Serial.println(F("[BLE TX] ERROR: DataScheduler not initialized!"));
    return;
  }

  // ROBUST CONNECTION DETECTION: Check actual connection status
  // (fallback if onConnect callback doesn't fire)
  uint16_t actualConnectedCount = 0;
  if (pServer) {
    actualConnectedCount = pServer->getConnectedCount();
  }

  // Sync deviceConnected flag with actual connection state
  bool actuallyConnected = (actualConnectedCount > 0);

  if (actuallyConnected && !deviceConnected) {
    // Connection exists but flag wasn't set (callback didn't fire)
    deviceConnected = true;
    Serial.println(F("========================================"));
    Serial.println(F("[BLE TX] ⚠️ Connection detected via fallback mechanism!"));
    Serial.println(F("[BLE TX] (onConnect callback did not fire)"));
    Serial.print(F("[BLE TX] Connected clients: "));
    Serial.println(actualConnectedCount);
    Serial.println(F("========================================"));
  } else if (!actuallyConnected && deviceConnected) {
    // Flag says connected but no actual connection
    deviceConnected = false;
    Serial.println(F("[BLE TX] Connection lost - flag updated"));
  }

  if (!deviceConnected) {
    // Log diagnostic info periodically (every 10 seconds)
    if (currentTime - lastDiagnosticLog >= 10000) {
      lastDiagnosticLog = currentTime;
      Serial.println(F("========================================"));
      Serial.println(F("[BLE TX] processDataQueue() Status"));
      Serial.println(F("========================================"));
      Serial.print(F("  deviceConnected flag: "));
      Serial.println(deviceConnected ? "YES" : "NO ❌");
      Serial.print(F("  Actual connections: "));
      Serial.println(actualConnectedCount);
      Serial.print(F("  dataScheduler: "));
      Serial.println(dataScheduler ? "OK" : "NULL ❌");
      Serial.println(F("  → BLE not connected - waiting for client..."));
      Serial.println(F("========================================"));
    }
    return;
  }

  // Reset diagnostic timer when connected
  lastDiagnosticLog = 0;

  // Process packets from DataScheduler (priority-ordered)
  DataPacket packet;
  while (dataScheduler->getNextPacket(packet, 0)) {  // Non-blocking
    switch (packet.type) {
      case DATA_ALERT:
        Serial.print(F("[BLE TX] 🚨 Dequeued ALERT: "));
        Serial.write(packet.data, packet.dataSize);
        Serial.print(F(" ("));
        Serial.print(packet.dataSize);
        Serial.println(F(" bytes)"));
        if (pAlertCharacteristic) {
          pAlertCharacteristic->setValue(packet.data, packet.dataSize);
          pAlertCharacteristic->notify();
          Serial.println(F("[BLE TX] ✅ Alert notification sent via BLE"));
        } else {
          Serial.println(F("[BLE TX] ❌ ERROR: Alert characteristic NULL!"));
        }
        break;

      case DATA_HEART_RATE:
        Serial.print(F("[BLE TX] ❤️ Dequeued HEART RATE: "));
        Serial.print(packet.data[0]);
        Serial.println(F(" BPM"));
        if (pHRCharacteristic) {
          pHRCharacteristic->setValue(packet.data, packet.dataSize);
          pHRCharacteristic->notify();
          Serial.println(F("[BLE TX] ✅ Heart rate notification sent via BLE"));
        } else {
          Serial.println(F("[BLE TX] ❌ ERROR: HR characteristic NULL!"));
        }
        break;

      case DATA_AUDIO:
        // Reduced verbosity for audio (high frequency)
        static uint32_t audioPacketCount = 0;
        audioPacketCount++;
        if (audioPacketCount % 50 == 0) {  // Log every 50th packet
          Serial.print(F("[BLE TX] 🎤 Audio packet #"));
          Serial.print(audioPacketCount);
          Serial.print(F(": "));
          Serial.print(packet.dataSize);
          Serial.println(F(" bytes (ADPCM compressed)"));
        }
        if (pAudioCharacteristic) {
          // Send ADPCM-compressed audio
          pAudioCharacteristic->setValue(packet.data, packet.dataSize);
          pAudioCharacteristic->notify();
        }
        break;
    }

    // Yield to avoid blocking other tasks
    yield();
  }
}

// ============================================================================
// CONNECTION PARAMETER OPTIMIZATION
// ============================================================================

void BLEManager::requestConnectionUpdate() {
  if (!deviceConnected || !pServer) {
    return;
  }

  // Note: NimBLE automatically negotiates optimal connection parameters
  // The iOS/Android central device typically controls these parameters
  // We log our preferred values for reference

  connectionParamsUpdated = true;

  Serial.println(F("[BLE] Connection parameters (controlled by central device):"));
  Serial.print(F("  - Preferred interval: 15ms (optimized for throughput)"));
  Serial.println();
  Serial.print(F("  - Preferred latency: 0 (immediate response)"));
  Serial.println();
  Serial.print(F("  - Preferred timeout: 5000ms (prevent disconnects)"));
  Serial.println();
  Serial.println(F("[BLE] Note: Central device (iPhone) controls actual parameters"));
}

void BLEManager::requestMTUUpdate() {
  if (!deviceConnected || !pServer) {
    return;
  }

  // NimBLE automatically negotiates MTU
  // We can retrieve the negotiated MTU after connection
  std::vector<uint16_t> connIds = pServer->getPeerDevices();
  if (!connIds.empty()) {
    currentMTU = pServer->getPeerMTU(connIds[0]);
    Serial.print(F("[BLE] Negotiated MTU: "));
    Serial.print(currentMTU);
    Serial.println(F(" bytes"));

    if (currentMTU < BLE_REQUESTED_MTU) {
      Serial.print(F("[BLE] WARNING: MTU smaller than requested ("));
      Serial.print(BLE_REQUESTED_MTU);
      Serial.println(F(" bytes)"));
    }
  }
}
