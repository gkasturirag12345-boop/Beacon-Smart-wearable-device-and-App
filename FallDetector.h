/*
 * Fall Detector Module
 * Handles BNO085 IMU for fall detection and motion wake-up
 */

#ifndef FALL_DETECTOR_H
#define FALL_DETECTOR_H

#include <Adafruit_BNO08x.h>
#include "Config.h"

class FallDetector {
public:
  FallDetector();

  bool begin();
  void update();
  bool checkMotionForWake();

  // Getters
  bool isFallDetected() const { return fallDetected; }
  float getCurrentAccelMagnitude() const { return currentLinearAccelMagnitude; }

  // Setters
  void resetFallDetection() { fallDetected = false; }

  // Callback for fall alert
  void setFallCallback(void (*callback)());

private:
  Adafruit_BNO08x bno08x;
  sh2_SensorValue_t sensorValue;

  // Fall detection state
  bool fallDetected;
  bool highAccelDetected;
  uint32_t highAccelTime;
  uint32_t lastIMUUpdate;
  float currentLinearAccelMagnitude;

  // Callback
  void (*fallCallback)();
};

#endif // FALL_DETECTOR_H
