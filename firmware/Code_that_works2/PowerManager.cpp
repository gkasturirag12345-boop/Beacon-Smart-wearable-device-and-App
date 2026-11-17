/*
 * Power Manager Implementation
 */

#include "PowerManager.h"

PowerManager::PowerManager()
  : powerState(ACTIVE),
    notWornStartTime(0),
    lastActivityTime(0),
    startupTime(0),
    inLightSleep(false),
    dimCallback(nullptr),
    restoreCallback(nullptr),
    bleStopCallback(nullptr),
    bleStartCallback(nullptr),
    motionCallback(nullptr),
    wearCheckCallback(nullptr) {
}

void PowerManager::begin(unsigned long currentTime) {
  startupTime = currentTime;
  lastActivityTime = currentTime;
  powerState = ACTIVE;
}

void PowerManager::update(bool deviceConnected, bool isWorn) {
  uint32_t currentTime = millis();

  // Skip during startup grace period
  if (currentTime - startupTime < STARTUP_GRACE_PERIOD) {
    return;
  }

  // Power state machine
  switch (powerState) {
    case ACTIVE:
      if (!isWorn && notWornStartTime == 0) {
        notWornStartTime = currentTime;
        powerState = WORN_CHECK;
        Serial.println(F("========================================"));
        Serial.println(F("[Power] → WORN_CHECK"));
        Serial.println(F("[Status] Device removed, starting 60s countdown"));
        Serial.println(F("========================================"));
      }
      break;

    case WORN_CHECK:
      if (isWorn) {
        powerState = ACTIVE;
        notWornStartTime = 0;
        Serial.println(F("========================================"));
        Serial.println(F("[Power] → ACTIVE"));
        Serial.println(F("[Status] Device worn again, countdown cancelled"));
        Serial.println(F("========================================"));
      } else if (currentTime - notWornStartTime >= NOT_WORN_TIMEOUT) {
        powerState = TRANSITION_SLEEP;
        Serial.println(F("========================================"));
        Serial.println(F("[Power] → TRANSITION_SLEEP"));
        Serial.println(F("[Status] 60 seconds elapsed, preparing for low power mode"));
        Serial.println(F("========================================"));
      } else {
        // Countdown
        static unsigned long lastCountdownPrint = 0;
        if (currentTime - lastCountdownPrint >= 10000) {
          int secondsRemaining = (NOT_WORN_TIMEOUT - (currentTime - notWornStartTime)) / 1000;
          Serial.print(F("[Power] Countdown: "));
          Serial.print(secondsRemaining);
          Serial.println(F(" seconds until low power mode"));
          lastCountdownPrint = currentTime;
        }
      }
      break;

    case TRANSITION_SLEEP:
      if (isWorn) {
        powerState = ACTIVE;
        notWornStartTime = 0;
        Serial.println(F("========================================"));
        Serial.println(F("[Power] → ACTIVE"));
        Serial.println(F("[Status] Sleep aborted - device worn again"));
        Serial.println(F("========================================"));
      } else if (motionCallback && motionCallback()) {
        powerState = ACTIVE;
        notWornStartTime = 0;
        Serial.println(F("========================================"));
        Serial.println(F("[Power] → ACTIVE"));
        Serial.println(F("[Status] Sleep aborted - motion detected"));
        Serial.println(F("========================================"));
      } else {
        Serial.println(F("========================================"));
        Serial.println(F("[Power] All checks passed, entering sleep mode"));
        Serial.println(F("========================================"));
        enterLightSleep();
      }
      break;

    case LIGHT_SLEEP:
      Serial.println(F("[Power] ERROR: LIGHT_SLEEP state in main loop - forcing ACTIVE"));
      powerState = ACTIVE;
      break;

    case DEEP_SLEEP:
      if (!deviceConnected && (currentTime - lastActivityTime > IDLE_TIMEOUT_DEEP_SLEEP)) {
        Serial.println(F("========================================"));
        Serial.println(F("[Power] → DEEP_SLEEP"));
        Serial.println(F("[Reason] No BLE connection + idle timeout"));
        Serial.println(F("========================================"));
        enterDeepSleep();
      }
      break;
  }

  // Separate deep sleep check
  if (powerState == ACTIVE && !deviceConnected && (currentTime - lastActivityTime > IDLE_TIMEOUT_DEEP_SLEEP)) {
    Serial.println(F("[Power] → DEEP_SLEEP: No BLE connection and idle timeout"));
    enterDeepSleep();
  }
}

void PowerManager::configureWakeupSources() {
  esp_sleep_enable_gpio_wakeup();
  gpio_wakeup_enable((gpio_num_t)BUTTON_PIN, GPIO_INTR_LOW_LEVEL);
  esp_sleep_enable_timer_wakeup(LIGHT_SLEEP_DURATION);

  Serial.println(F("[Power] Wake-up sources configured:"));
  Serial.println(F("  - Button press (GPIO 7)"));
  Serial.println(F("  - Timer (5 seconds)"));
}

void PowerManager::enterLightSleep() {
  Serial.println(F("========================================"));
  Serial.println(F("[Power] Entering LIGHT SLEEP mode"));
  Serial.println(F("========================================"));

  inLightSleep = true;
  powerState = LIGHT_SLEEP;

  if (dimCallback) dimCallback();
  if (bleStopCallback) bleStopCallback();

  configureWakeupSources();

  Serial.println(F("[Power] Entering sleep loop..."));
  Serial.flush();

  while (powerState == LIGHT_SLEEP) {
    esp_light_sleep_start();

    esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();

    switch (wakeup_reason) {
      case ESP_SLEEP_WAKEUP_GPIO:
        Serial.println(F("[Wake] Button pressed - exiting sleep mode"));
        wakeFromLightSleep();
        return;

      case ESP_SLEEP_WAKEUP_TIMER: {
        Serial.println(F("[Wake] Timer - checking sensors..."));

        if (wearCheckCallback) wearCheckCallback();

        // Check wear status through external callback
        bool isWornNow = false;
        if (wearCheckCallback) {
          // This callback should update wear detection internally
          // We'll check the result through the main update() call
          isWornNow = true; // Placeholder - actual check done externally
        }

        if (motionCallback && motionCallback()) {
          Serial.println(F("[Wake] Motion detected - exiting sleep"));
          wakeFromLightSleep();
          return;
        }

        Serial.println(F("[Sleep] Still not worn, returning to sleep..."));
        break;
      }

      default:
        Serial.println(F("[Wake] Unknown cause - checking conditions"));
        break;
    }
  }

  inLightSleep = false;
  lastActivityTime = millis();
}

void PowerManager::wakeFromLightSleep() {
  Serial.println(F("========================================"));
  Serial.println(F("[Power] WAKING from light sleep"));
  Serial.println(F("========================================"));

  if (restoreCallback) restoreCallback();
  if (bleStartCallback) bleStartCallback();

  inLightSleep = false;
  powerState = ACTIVE;
  notWornStartTime = 0;
  lastActivityTime = millis();

  Serial.println(F("[Power] → ACTIVE: Fully awake and operational"));
  Serial.println(F("========================================"));
}

void PowerManager::handleWakeup() {
  wakeFromLightSleep();
}

void PowerManager::enterDeepSleep() {
  Serial.println(F("========================================"));
  Serial.println(F("[Power] Entering DEEP SLEEP mode"));
  Serial.println(F("[Power] Will wake up in 10 seconds"));
  Serial.println(F("========================================"));
  Serial.flush();

  esp_sleep_enable_gpio_wakeup();
  gpio_wakeup_enable((gpio_num_t)BUTTON_PIN, GPIO_INTR_LOW_LEVEL);
  esp_sleep_enable_timer_wakeup(WAKE_CHECK_INTERVAL);

  esp_deep_sleep_start();
}

void PowerManager::setSensorDimCallback(void (*callback)()) {
  dimCallback = callback;
}

void PowerManager::setSensorRestoreCallback(void (*callback)()) {
  restoreCallback = callback;
}

void PowerManager::setBLEStopCallback(void (*callback)()) {
  bleStopCallback = callback;
}

void PowerManager::setBLEStartCallback(void (*callback)()) {
  bleStartCallback = callback;
}

void PowerManager::setMotionCheckCallback(bool (*callback)()) {
  motionCallback = callback;
}

void PowerManager::setWearCheckCallback(void (*callback)()) {
  wearCheckCallback = callback;
}
