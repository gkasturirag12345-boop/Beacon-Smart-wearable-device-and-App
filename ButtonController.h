/*
 * Button Controller Module
 * Handles button debouncing and single/double press detection
 */

#ifndef BUTTON_CONTROLLER_H
#define BUTTON_CONTROLLER_H

#include "Config.h"
#include <Arduino.h>

class ButtonController {
public:
  ButtonController();

  void begin();
  void update();

  // Callbacks
  void setManualAlertCallback(void (*callback)());
  void setFalseAlarmCallback(void (*callback)());

private:
  bool lastButtonState;
  bool currentButtonState;
  uint32_t lastDebounceTime;
  uint32_t firstPressTime;
  uint8_t pressCount;
  bool waitingForSecondPress;

  // Callbacks
  void (*manualAlertCallback)();
  void (*falseAlarmCallback)();
};

#endif // BUTTON_CONTROLLER_H
