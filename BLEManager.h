/*
 * BLE Manager Module
 * Handles NimBLE setup, characteristics, and notifications
 * Uses NimBLE-Arduino library (much smaller than full BLE stack)
 * Includes connection parameter optimization and DataScheduler integration
 */

#ifndef BLE_MANAGER_H
#define BLE_MANAGER_H

#include <NimBLEDevice.h>
#include "Config.h"
#include "DataScheduler.h"

class BLEManager {
public:
  BLEManager();

  void begin();
  void update();
  void stopAdvertising();
  void startAdvertising();
  bool isAdvertising();

  // DataScheduler integration
  void setDataScheduler(DataScheduler* scheduler);
  DataScheduler* getDataScheduler() { return dataScheduler; }

  // Optimized data transmission via DataScheduler
  void processDataQueue();  // Process and transmit queued packets

  // Legacy direct transmission (deprecated - use DataScheduler)
  void notifyHeartRate(uint8_t hr);
  void notifyAlert(const char* alertType);
  void notifyAudio(const uint8_t* audioData, size_t length);

  // Getters
  bool isConnected() const { return deviceConnected; }
  NimBLEServer* getServer() { return pServer; }
  uint16_t getCurrentMTU() const { return currentMTU; }

  // Callbacks for control commands
  void setResetAlertCallback(void (*callback)());
  void setTriggerFallCallback(void (*callback)());

private:
  NimBLEServer* pServer;
  NimBLECharacteristic* pHRCharacteristic;
  NimBLECharacteristic* pAlertCharacteristic;
  NimBLECharacteristic* pControlCharacteristic;
  NimBLECharacteristic* pAudioCharacteristic;  // Audio streaming

  bool deviceConnected;
  bool oldDeviceConnected;
  uint16_t currentMTU;
  bool connectionParamsUpdated;

  // DataScheduler for priority-based transmission
  DataScheduler* dataScheduler;

  // Callbacks
  void (*resetAlertCallback)();
  void (*triggerFallCallback)();

  // Connection parameter optimization
  void requestConnectionUpdate();
  void requestMTUUpdate();

  // Server callbacks
  class ServerCallbacks : public NimBLEServerCallbacks {
  public:
    ServerCallbacks(BLEManager* manager) : bleManager(manager) {}
    void onConnect(NimBLEServer* pServer);
    void onDisconnect(NimBLEServer* pServer);
  private:
    BLEManager* bleManager;
  };

  // Control characteristic callbacks
  class ControlCallbacks : public NimBLECharacteristicCallbacks {
  public:
    ControlCallbacks(BLEManager* manager) : bleManager(manager) {}
    void onWrite(NimBLECharacteristic* pCharacteristic);
  private:
    BLEManager* bleManager;
  };

  friend class ServerCallbacks;
  friend class ControlCallbacks;
};

#endif // BLE_MANAGER_H
