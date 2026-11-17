/*
 * Button Controller Implementation
 */

#include "ButtonController.h"

ButtonController::ButtonController()
  : lastButtonState(HIGH),
    currentButtonState(HIGH),
    lastDebounceTime(0),
    firstPressTime(0),
    pressCount(0),
    waitingForSecondPress(false),
    manualAlertCallback(nullptr),
    falseAlarmCallback(nullptr) {
}

void ButtonController::begin() {
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  Serial.println(F("Button initialized on GPIO 3"));
}

void ButtonController::update() {
  uint32_t currentTime = millis();

  int reading = digitalRead(BUTTON_PIN);

  if (reading != lastButtonState) {
    lastDebounceTime = currentTime;
  }

  if ((currentTime - lastDebounceTime) > DEBOUNCE_DELAY) {
    if (reading != currentButtonState) {
      currentButtonState = reading;

      if (currentButtonState == LOW) {
        // Button pressed
        pressCount++;
        Serial.print(F("[Button] Press detected! Count: "));
        Serial.println(pressCount);

        if (pressCount == 1) {
          firstPressTime = currentTime;
          waitingForSecondPress = true;
          Serial.println(F("[Button] First press - waiting for second press..."));
        } else if (pressCount == 2) {
          Serial.println(F("========================================"));
          Serial.println(F("[Button] DOUBLE PRESS detected!"));
          Serial.println(F("========================================"));
          if (falseAlarmCallback) falseAlarmCallback();
          Serial.println(F("[Button] False alarm notification sent via BLE"));
          pressCount = 0;
          waitingForSecondPress = false;
        }
      }
    }
  }

  // Check for single press timeout
  if (waitingForSecondPress && (currentTime - firstPressTime > DOUBLE_PRESS_WINDOW)) {
    Serial.println(F("========================================"));
    Serial.println(F("[Button] SINGLE PRESS confirmed (timeout)"));
    Serial.println(F("[Button] Triggering MANUAL ALERT"));
    Serial.println(F("========================================"));
    if (manualAlertCallback) manualAlertCallback();
    Serial.println(F("[Button] Manual alert notification sent via BLE"));
    pressCount = 0;
    waitingForSecondPress = false;
  }

  lastButtonState = reading;
}

void ButtonController::setManualAlertCallback(void (*callback)()) {
  manualAlertCallback = callback;
}

void ButtonController::setFalseAlarmCallback(void (*callback)()) {
  falseAlarmCallback = callback;
}
