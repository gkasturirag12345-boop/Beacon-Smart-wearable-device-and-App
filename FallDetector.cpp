/*
 * Fall Detector Implementation
 */

#include "FallDetector.h"

FallDetector::FallDetector()
  : fallDetected(false),
    highAccelDetected(false),
    highAccelTime(0),
    lastIMUUpdate(0),
    currentLinearAccelMagnitude(0),
    fallCallback(nullptr) {
}

bool FallDetector::begin() {
  Serial.println(F("Initializing BNO085..."));

  if (!bno08x.begin_I2C()) {
    Serial.println(F("ERROR: BNO085 not found"));
    return false;
  }

  if (!bno08x.enableReport(SH2_LINEAR_ACCELERATION, IMU_UPDATE_INTERVAL * 1000)) {
    Serial.println(F("ERROR: Could not enable linear acceleration"));
    return false;
  }

  Serial.println(F("BNO085 initialized successfully"));
  return true;
}

void FallDetector::update() {
  uint32_t currentTime = millis();

  if (currentTime - lastIMUUpdate < IMU_UPDATE_INTERVAL) {
    return;
  }

  lastIMUUpdate = currentTime;

  if (!bno08x.getSensorEvent(&sensorValue)) {
    return;
  }

  if (sensorValue.sensorId == SH2_LINEAR_ACCELERATION) {
    float x = sensorValue.un.linearAcceleration.x;
    float y = sensorValue.un.linearAcceleration.y;
    float z = sensorValue.un.linearAcceleration.z;

    currentLinearAccelMagnitude = sqrt(x * x + y * y + z * z);

    // Detect high acceleration spike
    if (!highAccelDetected && currentLinearAccelMagnitude > FALL_ACCEL_THRESHOLD) {
      highAccelDetected = true;
      highAccelTime = currentTime;
      Serial.print(F("High acceleration detected: "));
      Serial.print(currentLinearAccelMagnitude);
      Serial.println(F(" m/s²"));
    }

    // Check for stationary period after spike
    if (highAccelDetected && !fallDetected) {
      uint32_t timeSinceSpike = currentTime - highAccelTime;

      if (currentLinearAccelMagnitude < FALL_MOTION_THRESHOLD) {
        if (timeSinceSpike >= FALL_STATIONARY_TIME) {
          fallDetected = true;
          if (fallCallback) fallCallback();
          highAccelDetected = false;
        }
      } else {
        if (timeSinceSpike > FALL_STATIONARY_TIME + 1000) {
          highAccelDetected = false;
        }
      }
    }
  }
}

bool FallDetector::checkMotionForWake() {
  if (!bno08x.getSensorEvent(&sensorValue)) {
    return false;
  }

  if (sensorValue.sensorId == SH2_LINEAR_ACCELERATION) {
    float x = sensorValue.un.linearAcceleration.x;
    float y = sensorValue.un.linearAcceleration.y;
    float z = sensorValue.un.linearAcceleration.z;

    float magnitude = sqrt(x * x + y * y + z * z);

    if (magnitude > MOTION_WAKE_THRESHOLD) {
      Serial.print(F("[Motion] Wake-up triggered! Magnitude: "));
      Serial.print(magnitude);
      Serial.println(F(" m/s²"));
      return true;
    }
  }

  return false;
}

void FallDetector::setFallCallback(void (*callback)()) {
  fallCallback = callback;
}
