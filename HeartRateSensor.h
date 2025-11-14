/*
 * Heart Rate Sensor Module
 * Handles MAX30105 sensor for heart rate monitoring and IR-based wear detection
 */

#ifndef HEART_RATE_SENSOR_H
#define HEART_RATE_SENSOR_H

#include <MAX30105.h>
#include <heartRate.h>
#include "Config.h"

class HeartRateSensor {
public:
  HeartRateSensor();

  bool begin();
  void update();
  void updateWearDetection();

  // Power management
  void dimForSleep();
  bool restoreFromSleep();

  // Getters
  uint8_t getCurrentHeartRate() const { return currentHeartRate; }
  float getCurrentIRValue() const { return currentIRValue; }
  bool isWorn() const { return wearDetectedFromIR; }
  bool isHeartStopAlert() const { return heartStopAlertSent; }

  // Setters
  void resetHeartStopAlert() { heartStopAlertSent = false; }

  // Callback for BLE notification
  void setHeartRateCallback(void (*callback)(uint8_t hr));
  void setWearStatusCallback(void (*callback)(bool worn));
  void setHeartStopCallback(void (*callback)());

private:
  MAX30105 particleSensor;

  // Heart rate state
  uint32_t lastBeatTime;
  uint32_t lastHRSampleTime;
  uint32_t lastHRUpdateTime;  // Last time HR was transmitted (for 1 Hz throttling)
  uint8_t currentHeartRate;
  byte rates[HR_AVERAGE_SIZE];
  byte rateSpot;
  long lastBeat;
  bool heartStopAlertSent;

  // Wear detection state
  unsigned long lastIRCheck;
  float currentIRValue;
  bool wearDetectedFromIR;
  bool deviceWorn;
  bool pendingWearState;       // Wear state waiting to be confirmed
  uint32_t wearStateChangeTime; // When wear state change was first detected
  static const uint32_t WEAR_DEBOUNCE_DELAY = 3000;  // 3 seconds

  // Callbacks
  void (*hrCallback)(uint8_t);
  void (*wearCallback)(bool);
  void (*heartStopCallback)();
};

#endif // HEART_RATE_SENSOR_H
