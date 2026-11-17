/*
 * Power Manager Module
 * Handles power state machine, sleep modes, and wake-up logic
 */

#ifndef POWER_MANAGER_H
#define POWER_MANAGER_H

#include <Arduino.h>
#include "Config.h"
#include "esp_sleep.h"
#include "driver/gpio.h"

class PowerManager {
public:
  PowerManager();

  void begin(unsigned long currentTime);
  void update(bool deviceConnected, bool isWorn);
  void handleWakeup();

  // Getters
  PowerState getCurrentState() const { return powerState; }
  bool isInLightSleep() const { return inLightSleep; }
  unsigned long getLastActivityTime() const { return lastActivityTime; }

  // Setters
  void recordActivity() { lastActivityTime = millis(); }

  // Callbacks for sensor control
  void setSensorDimCallback(void (*callback)());
  void setSensorRestoreCallback(void (*callback)());
  void setBLEStopCallback(void (*callback)());
  void setBLEStartCallback(void (*callback)());
  void setMotionCheckCallback(bool (*callback)());
  void setWearCheckCallback(void (*callback)());

private:
  PowerState powerState;
  unsigned long notWornStartTime;
  unsigned long lastActivityTime;
  unsigned long startupTime;
  bool inLightSleep;

  // Callbacks
  void (*dimCallback)();
  void (*restoreCallback)();
  void (*bleStopCallback)();
  void (*bleStartCallback)();
  bool (*motionCallback)();
  void (*wearCheckCallback)();

  // Internal methods
  void configureWakeupSources();
  void enterLightSleep();
  void wakeFromLightSleep();
  void enterDeepSleep();
};

#endif // POWER_MANAGER_H
