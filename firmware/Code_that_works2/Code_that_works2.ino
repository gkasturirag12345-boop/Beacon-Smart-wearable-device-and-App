/*
 * ESP32-C3 CodeCell Health Monitor - BLE-Only Version
 * Optimized firmware for heart rate monitoring, fall detection, and power management
 *
 * Hardware:
 * - ESP32-C3 CodeCell with BNO085 IMU and VCNL4040 proximity sensor
 * - MAX30105 heart rate sensor (I2C)
 * - Push button on GPIO 3 for manual alerts
 * - I2S microphone on GPIO 5/6/7 for audio detection
 *
 * Features:
 * - Continuous heart rate monitoring with heart stop detection
 * - Fall detection using IMU linear acceleration
 * - BLE communication (NimBLE for reduced flash usage)
 * - Audio-based alert detection (thuds and distress sounds)
 * - Power management with light/deep sleep modes
 * - Button-controlled alert system (single press = alert, double = false alarm)
 */

#include <Wire.h>
#include <Adafruit_VCNL4040.h>

// Modular components
#include "Config.h"
#include "DataScheduler.h"  // Priority-based BLE transmission
#include "BLEManager.h"
#include "HeartRateSensor.h"
#include "FallDetector.h"
#include "PowerManager.h"
#include "ButtonController.h"
#include "AudioDetector.h"


// ============================================================================
// GLOBAL OBJECTS
// ============================================================================

Adafruit_VCNL4040 vcnl4040;

// Initialize DataScheduler first (needed by BLE and Audio)
DataScheduler dataScheduler;

BLEManager bleManager;
HeartRateSensor hrSensor;
FallDetector fallDetector;
PowerManager powerManager;
ButtonController buttonController;
AudioDetector audioDetector;

// Proximity detection
bool deviceWorn = true;
uint32_t lastProximityCheck = 0;

// Global variables (no longer used - web server removed)
uint8_t currentHeartRate = 0;
bool fallDetected = false;
bool wearDetectedFromIR = false;


// ============================================================================
// BLE CALLBACK WRAPPERS (Using DataScheduler for priority-based transmission)
// ============================================================================

void onHeartRateUpdate(uint8_t hr) {
  currentHeartRate = hr;  // Update global
  // Enqueue heart rate update via DataScheduler (HIGH priority)
  dataScheduler.enqueueHeartRate(hr);
}

void onWearStatusChange(bool worn) {
  wearDetectedFromIR = worn;  // Update global
  // Enqueue wear status alert via DataScheduler (CRITICAL priority)
  if (worn) {
    dataScheduler.enqueueAlert("DEVICE_WORN");
    powerManager.recordActivity();
  } else {
    dataScheduler.enqueueAlert("DEVICE_NOT_WORN");
  }
}

void onHeartStopDetected() {
  Serial.println(F("ALERT: HEART_STOP detected!"));
  // Enqueue critical alert via DataScheduler (CRITICAL priority)
  dataScheduler.enqueueAlert("HEART_STOP");
  powerManager.recordActivity();
}

void onFallDetected() {
  fallDetected = true;  // Update global
  Serial.println(F("ALERT: FALL_DETECTED!"));
  // Enqueue critical alert via DataScheduler (CRITICAL priority)
  dataScheduler.enqueueAlert("FALL_DETECTED");
  powerManager.recordActivity();
  delay(10000);
  fallDetector.resetFallDetection();
  fallDetected = false;  // Reset after handling
}

void onManualAlert() {
  Serial.println(F("========================================"));
  Serial.println(F("[ALERT] MANUAL ALERT - Single button press"));
  Serial.println(F("[BLE] Sending 'MANUAL_ALERT' notification"));
  Serial.println(F("========================================"));
  // Enqueue critical alert via DataScheduler (CRITICAL priority)
  dataScheduler.enqueueAlert("MANUAL_ALERT");
  powerManager.recordActivity();
}

void onFalseAlarm() {
  Serial.println(F("========================================"));
  Serial.println(F("[ALERT] FALSE ALARM - Double button press"));
  Serial.println(F("[BLE] Sending 'FALSE_ALARM' notification"));
  Serial.println(F("========================================"));
  // Enqueue alert via DataScheduler (CRITICAL priority)
  dataScheduler.enqueueAlert("FALSE_ALARM");
  powerManager.recordActivity();
}



void onResetAlert() {
  Serial.println(F("[BLE Control] Reset alert requested"));
  fallDetector.resetFallDetection();
  hrSensor.resetHeartStopAlert();
}

void onTriggerFall() {
  Serial.println(F("[BLE Control] Manual fall trigger requested"));
  onFallDetected();
}

// Note: Local audio callbacks disabled - all ML inference on iPhone
void onAudioThud() {
  // Disabled: Audio analysis now happens on iPhone via TensorFlow Lite
}

void onAudioDistress() {
  // Disabled: Audio analysis now happens on iPhone via TensorFlow Lite
}

// ============================================================================
// POWER MANAGEMENT CALLBACKS
// ============================================================================

void dimSensors() {
  hrSensor.dimForSleep();
}

void restoreSensors() {
  hrSensor.restoreFromSleep();
}

void stopBLE() {
  bleManager.stopAdvertising();
}

void startBLE() {
  bleManager.startAdvertising();
}

bool checkMotionForWake() {
  return fallDetector.checkMotionForWake();
}

void checkWearForWake() {
  hrSensor.updateWearDetection();
}

// ============================================================================
// PROXIMITY / WEAR DETECTION
// ============================================================================

void updateProximityCheck() {
  uint32_t currentTime = millis();

  if (currentTime - lastProximityCheck < PROXIMITY_CHECK_INTERVAL) {
    return;
  }

  lastProximityCheck = currentTime;

  uint16_t proximity = vcnl4040.getProximity();

  bool previousWornState = deviceWorn;
  deviceWorn = (proximity < PROXIMITY_WORN_THRESHOLD);

  if (previousWornState != deviceWorn) {
    if (deviceWorn) {
      Serial.println(F("Device worn - resuming monitoring"));
      powerManager.recordActivity();
    } else {
      Serial.println(F("Device not worn - pausing heart rate monitoring"));
    }
  }
}

// ============================================================================
// SENSOR INITIALIZATION
// ============================================================================

bool initVCNL4040() {
  Serial.println(F("Initializing VCNL4040..."));

  if (!vcnl4040.begin()) {
    Serial.println(F("ERROR: VCNL4040 not found"));
    return false;
  }

  Serial.println(F("VCNL4040 initialized successfully"));
  return true;
}

// ============================================================================
// ARDUINO SETUP
// ============================================================================

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println(F("\n\n================================="));
  Serial.println(F("ESP32-C3 Health Monitor Starting"));
  Serial.println(F("BLE-Only Build (WiFi Removed)"));
  Serial.println(F("=================================\n"));

  // Initialize I2C with explicit pins
  Serial.println(F("Initializing I2C bus..."));
  Serial.print(F("SDA: GPIO"));
  Serial.print(I2C_SDA_PIN);
  Serial.print(F(", SCL: GPIO"));
  Serial.println(I2C_SCL_PIN);

  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  Wire.setClock(400000);  // 400kHz
  delay(100);  // Allow I2C to stabilize

  // Scan I2C bus for connected devices
  Serial.println(F("\nScanning I2C bus (0x01-0x7F)..."));
  Serial.println(F("Expected devices:"));
  Serial.println(F("  - MAX30105 (Heart Rate): 0x57"));
  Serial.println(F("  - BNO085 (IMU): 0x4A or 0x4B"));
  Serial.println(F("  - VCNL4040 (Proximity): 0x60"));
  Serial.println(F("\nScanning..."));

  uint8_t devicesFound = 0;
  for (uint8_t addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    uint8_t error = Wire.endTransmission();

    if (error == 0) {
      Serial.print(F("  [FOUND] Device at 0x"));
      if (addr < 16) Serial.print(F("0"));
      Serial.print(addr, HEX);

      // Identify known devices
      if (addr == MAX30105_I2C_ADDR) {
        Serial.print(F(" - MAX30105 Heart Rate Sensor"));
      } else if (addr == BNO085_I2C_ADDR_1 || addr == BNO085_I2C_ADDR_2) {
        Serial.print(F(" - BNO085 IMU"));
      } else if (addr == VCNL4040_I2C_ADDR) {
        Serial.print(F(" - VCNL4040 Proximity Sensor"));
      } else {
        Serial.print(F(" - Unknown device"));
      }
      Serial.println();
      devicesFound++;
    }
  }

  if (devicesFound == 0) {
    Serial.println(F("\n[ERROR] No I2C devices found!"));
    Serial.println(F("Possible issues:"));
    Serial.println(F("  1. Wrong SDA/SCL pin configuration"));
    Serial.println(F("  2. Sensors not powered"));
    Serial.println(F("  3. Missing pull-up resistors"));
    Serial.println(F("  4. Wiring problem"));
    Serial.println(F("\nRetrying at 100kHz (slower speed)..."));

    Wire.setClock(100000);  // Try slower speed
    delay(100);

    // Retry scan at slower speed
    for (uint8_t addr = 1; addr < 127; addr++) {
      Wire.beginTransmission(addr);
      uint8_t error = Wire.endTransmission();

      if (error == 0) {
        Serial.print(F("  [FOUND] Device at 0x"));
        if (addr < 16) Serial.print(F("0"));
        Serial.println(addr, HEX);
        devicesFound++;
      }
    }

    if (devicesFound == 0) {
      Serial.println(F("\n[FATAL] Still no devices found at 100kHz"));
      Serial.println(F("Hardware issue - check wiring and power"));
    }
  } else {
    Serial.print(F("\nI2C scan complete: "));
    Serial.print(devicesFound);
    Serial.println(F(" device(s) found"));
  }

  Serial.println(F("=================================\n"));

  // Initialize button
  buttonController.begin();

  // Initialize sensors
  if (!hrSensor.begin()) {
    Serial.println(F("FATAL: MAX30105 initialization failed"));
    while (1);
  }

  if (!initVCNL4040()) {
    Serial.println(F("FATAL: VCNL4040 initialization failed"));
    while (1);
  }

  if (!fallDetector.begin()) {
    Serial.println(F("FATAL: BNO085 initialization failed"));
    while (1);
  }

  // Initialize DataScheduler (priority-based BLE transmission)
  if (!dataScheduler.begin(10, 10, 20)) {  // Critical, High, Normal queue sizes
    Serial.println(F("FATAL: DataScheduler initialization failed"));
    while (1);
  }

  // Initialize BLE Manager and connect to DataScheduler
  bleManager.begin();
  bleManager.setDataScheduler(&dataScheduler);

  // Initialize audio detector (optional - may not have microphone)
  if (!audioDetector.begin()) {
    Serial.println(F("WARNING: I2S microphone initialization failed"));
    Serial.println(F("Audio detection disabled - continuing without microphone"));
  } else {
    // Connect audio detector to DataScheduler for compressed streaming
    audioDetector.setDataScheduler(&dataScheduler);
    audioDetector.enableStreaming(true);  // Enable ADPCM-compressed BLE streaming
    audioDetector.setAdaptiveRate(true);  // Enable VAD-based adaptive rate
    Serial.println(F("[Audio] ADPCM-compressed streaming configured for iOS SOS detection"));
  }

  // Set up BLE callbacks
  bleManager.setResetAlertCallback(onResetAlert);
  bleManager.setTriggerFallCallback(onTriggerFall);

  // Set up sensor callbacks
  hrSensor.setHeartRateCallback(onHeartRateUpdate);
  hrSensor.setWearStatusCallback(onWearStatusChange);
  hrSensor.setHeartStopCallback(onHeartStopDetected);
  fallDetector.setFallCallback(onFallDetected);
  buttonController.setManualAlertCallback(onManualAlert);
  buttonController.setFalseAlarmCallback(onFalseAlarm);
  audioDetector.setThudCallback(onAudioThud);
  audioDetector.setDistressCallback(onAudioDistress);

  // Set up power management callbacks
  powerManager.setSensorDimCallback(dimSensors);
  powerManager.setSensorRestoreCallback(restoreSensors);
  powerManager.setBLEStopCallback(stopBLE);
  powerManager.setBLEStartCallback(startBLE);
  powerManager.setMotionCheckCallback(checkMotionForWake);
  powerManager.setWearCheckCallback(checkWearForWake);

  // Initialize power manager
  powerManager.begin(millis());

  Serial.println(F("\n================================="));
  Serial.println(F("Setup complete - monitoring started"));
  Serial.println(F("=================================\n"));
}

// ============================================================================
// ARDUINO MAIN LOOP
// ============================================================================

void loop() {
  // Update BLE manager
  bleManager.update();

  // Process DataScheduler queue (priority-based BLE transmission)
  bleManager.processDataQueue();

  // Update button controller
  buttonController.update();

  // Update proximity/wear detection
  updateProximityCheck();

  // Update IR-based wear detection
  hrSensor.updateWearDetection();

  // Update heart rate monitoring
  hrSensor.update();

  // Update fall detection
  fallDetector.update();

  // Update audio detection (includes ADPCM compression & VAD)
  audioDetector.update();

  // Manage power modes
  powerManager.update(bleManager.isConnected(), hrSensor.isWorn());

  // Print DataScheduler statistics every 10 seconds (diagnostic logging)
  static uint32_t lastStatsTime = 0;
  uint32_t currentTime = millis();
  if (currentTime - lastStatsTime >= 10000) {
    lastStatsTime = currentTime;
    dataScheduler.printStatistics();
  }

  yield();
}
