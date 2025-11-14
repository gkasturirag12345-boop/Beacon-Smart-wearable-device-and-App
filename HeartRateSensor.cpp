/*
 * Heart Rate Sensor Implementation
 */

#include "HeartRateSensor.h"
#include <Wire.h>

HeartRateSensor::HeartRateSensor()
  : lastBeatTime(0),
    lastHRSampleTime(0),
    lastHRUpdateTime(0),
    currentHeartRate(0),
    rateSpot(0),
    lastBeat(0),
    heartStopAlertSent(false),
    lastIRCheck(0),
    currentIRValue(0),
    wearDetectedFromIR(true),
    deviceWorn(true),
    pendingWearState(true),
    wearStateChangeTime(0),
    hrCallback(nullptr),
    wearCallback(nullptr),
    heartStopCallback(nullptr) {
  memset(rates, 0, sizeof(rates));
}

bool HeartRateSensor::begin() {
  Serial.println(F("Initializing MAX30105..."));

  if (!particleSensor.begin(Wire, I2C_SPEED_STANDARD)) {
    Serial.println(F("ERROR: MAX30105 not found"));
    return false;
  }

  byte ledBrightness = 0x1F;
  byte sampleAverage = 4;
  byte ledMode = 2;  // Red LED only
  int sampleRate = 400;
  int pulseWidth = 411;
  int adcRange = 4096;

  particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange);
  particleSensor.setPulseAmplitudeRed(0x0A);
  particleSensor.setPulseAmplitudeIR(0x1F);

  Serial.println(F("MAX30105 initialized successfully"));
  return true;
}

void HeartRateSensor::update() {
  if (!deviceWorn) {
    return;
  }

  uint32_t currentTime = millis();

  if (currentTime - lastHRSampleTime < HR_SAMPLE_INTERVAL) {
    return;
  }

  lastHRSampleTime = currentTime;

  long irValue = particleSensor.getIR();

  // Periodic diagnostic logging (every 5 seconds) for debugging
  static uint32_t lastHRDiagnostic = 0;
  if (currentTime - lastHRDiagnostic >= 5000) {
    lastHRDiagnostic = currentTime;
    Serial.println(F("========================================"));
    Serial.println(F("[HR Sensor] Diagnostic Status"));
    Serial.println(F("========================================"));
    Serial.print(F("  IR Value: "));
    Serial.print(irValue);
    Serial.print(F(" (threshold: 1000, current: "));
    Serial.print(irValue >= 1000 ? "✅ OK" : "❌ TOO LOW");
    Serial.println(F(")"));
    Serial.print(F("  Finger Detected: "));
    Serial.println(irValue >= 1000 ? "YES" : "NO");
    Serial.print(F("  Current Heart Rate: "));
    Serial.print(currentHeartRate);
    Serial.println(F(" BPM"));
    Serial.print(F("  Last Beat: "));
    Serial.print((currentTime - lastBeatTime) / 1000);
    Serial.println(F(" seconds ago"));
    if (irValue < 1000) {
      Serial.println(F("  → Place finger firmly on sensor"));
    }
    Serial.println(F("========================================"));
  }

  if (irValue < 1000) {
    if (currentTime - lastBeatTime > HR_NO_BEAT_TIMEOUT && !heartStopAlertSent) {
      currentHeartRate = 0;
      if (heartStopCallback) heartStopCallback();
      heartStopAlertSent = true;
    }
    return;
  }

  if (checkForBeat(irValue)) {
    long delta = currentTime - lastBeat;
    lastBeat = currentTime;
    lastBeatTime = currentTime;
    heartStopAlertSent = false;

    float beatsPerMinute = 60000.0 / delta;

    if (beatsPerMinute < 255 && beatsPerMinute > 20) {
      rates[rateSpot++] = (byte)beatsPerMinute;
      rateSpot %= HR_AVERAGE_SIZE;

      int beatAvg = 0;
      for (byte x = 0; x < HR_AVERAGE_SIZE; x++) {
        beatAvg += rates[x];
      }
      beatAvg /= HR_AVERAGE_SIZE;

      currentHeartRate = beatAvg;

      // Throttle heart rate updates to 1 Hz to save BLE bandwidth
      if (hrCallback && (currentTime - lastHRUpdateTime >= HR_UPDATE_INTERVAL)) {
        hrCallback(currentHeartRate);
        lastHRUpdateTime = currentTime;

        Serial.print(F("Heart Rate: "));
        Serial.print(currentHeartRate);
        Serial.println(F(" BPM"));
      }
    }
  }

  if (currentTime - lastBeatTime > HR_NO_BEAT_TIMEOUT && !heartStopAlertSent) {
    currentHeartRate = 0;
    if (heartStopCallback) heartStopCallback();
    heartStopAlertSent = true;
  }
}

void HeartRateSensor::updateWearDetection() {
  uint32_t currentTime = millis();

  if (currentTime - lastIRCheck < IR_CHECK_INTERVAL) {
    return;
  }

  lastIRCheck = currentTime;

  currentIRValue = particleSensor.getIR();

  // Determine current wear state from IR reading
  bool currentWearState = wearDetectedFromIR;  // Start with current confirmed state

  if (currentIRValue > IR_WEAR_THRESHOLD_HIGH) {
    currentWearState = true;
  } else if (currentIRValue < IR_WEAR_THRESHOLD_LOW) {
    currentWearState = false;
  }
  // If between thresholds, keep previous state (hysteresis)

  // Debouncing logic: only fire callback after state is stable for 3 seconds
  if (currentWearState != wearDetectedFromIR) {
    // State change detected
    if (wearStateChangeTime == 0) {
      // First detection of state change - start debounce timer
      wearStateChangeTime = currentTime;
      pendingWearState = currentWearState;
      Serial.print(F("[Wear] State change detected (IR: "));
      Serial.print(currentIRValue);
      Serial.print(F("), waiting "));
      Serial.print(WEAR_DEBOUNCE_DELAY / 1000);
      Serial.println(F("s for stability..."));
    } else if (pendingWearState != currentWearState) {
      // State flipped back - cancel pending change
      Serial.println(F("[Wear] State flipped back - cancelling pending change"));
      wearStateChangeTime = 0;
    } else if (currentTime - wearStateChangeTime >= WEAR_DEBOUNCE_DELAY) {
      // State has been stable for debounce period - confirm change
      wearDetectedFromIR = currentWearState;
      wearStateChangeTime = 0;

      if (wearDetectedFromIR) {
        Serial.print(F("[Wear] ✅ Device WORN confirmed (IR: "));
        Serial.print(currentIRValue);
        Serial.println(F(")"));
        if (wearCallback) wearCallback(true);
      } else {
        Serial.print(F("[Wear] ⚠️ Device REMOVED confirmed (IR: "));
        Serial.print(currentIRValue);
        Serial.println(F(")"));
        if (wearCallback) wearCallback(false);
      }
    }
  } else {
    // State matches confirmed state - reset debounce timer
    if (wearStateChangeTime != 0) {
      wearStateChangeTime = 0;
    }
  }
}

void HeartRateSensor::dimForSleep() {
  Serial.println(F("[Power] Dimming IR sensor (low power mode)..."));
  particleSensor.setPulseAmplitudeIR(0x05);
  particleSensor.setPulseAmplitudeRed(0x02);
  Serial.println(F("  - MAX30105 IR dimmed to 5/255"));
}

bool HeartRateSensor::restoreFromSleep() {
  Serial.println(F("[Power] Restoring IR sensor (full power)..."));
  particleSensor.setPulseAmplitudeIR(0x1F);
  particleSensor.setPulseAmplitudeRed(0x0A);
  delay(100);

  long irValue = particleSensor.getIR();
  Serial.print(F("  - Current IR reading: "));
  Serial.println(irValue);

  if (irValue == 0) {
    Serial.println(F("  - WARNING: IR still reading 0 - checking sensor..."));
    delay(200);
    irValue = particleSensor.getIR();
    Serial.print(F("  - Retry IR reading: "));
    Serial.println(irValue);
  }

  Serial.println(F("[Power] Sensor restore complete"));
  return true;
}

void HeartRateSensor::setHeartRateCallback(void (*callback)(uint8_t hr)) {
  hrCallback = callback;
}

void HeartRateSensor::setWearStatusCallback(void (*callback)(bool worn)) {
  wearCallback = callback;
}

void HeartRateSensor::setHeartStopCallback(void (*callback)()) {
  heartStopCallback = callback;
}
