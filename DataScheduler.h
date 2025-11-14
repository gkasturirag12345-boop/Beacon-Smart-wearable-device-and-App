/*
 * Data Scheduler for ESP32-C3 BEACON
 * Priority-based BLE data transmission using FreeRTOS queues
 *
 * Priority levels:
 * 1. CRITICAL: Alerts (FALL, HEART_STOP, MANUAL) - immediate transmission
 * 2. HIGH: Heart rate data - 1 Hz guaranteed
 * 3. NORMAL: Audio data - fills remaining bandwidth
 *
 * Prevents BLE bandwidth saturation by scheduling transmissions
 */

#ifndef DATA_SCHEDULER_H
#define DATA_SCHEDULER_H

#include <Arduino.h>
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"

// ============================================================================
// DATA PACKET TYPES
// ============================================================================

enum DataPriority {
  PRIORITY_CRITICAL = 0,  // Alerts - immediate
  PRIORITY_HIGH = 1,      // Heart rate - guaranteed 1 Hz
  PRIORITY_NORMAL = 2     // Audio - best effort
};

enum DataType {
  DATA_ALERT,
  DATA_HEART_RATE,
  DATA_AUDIO
};

// Maximum sizes for data payloads
#define MAX_ALERT_SIZE 32      // Alert strings are small
#define MAX_HR_SIZE 4          // Heart rate is 1-4 bytes
#define MAX_AUDIO_SIZE 244     // BLE MTU limit (247 - 3 byte header)

// ============================================================================
// DATA PACKET STRUCTURE
// ============================================================================

struct DataPacket {
  DataPriority priority;
  DataType type;
  uint32_t timestamp;  // millis() when packet was created
  uint16_t dataSize;
  uint8_t data[MAX_AUDIO_SIZE];  // Union-style data storage

  DataPacket() : priority(PRIORITY_NORMAL), type(DATA_AUDIO), timestamp(0), dataSize(0) {
    memset(data, 0, sizeof(data));
  }
};

// ============================================================================
// DATA SCHEDULER CLASS
// ============================================================================

class DataScheduler {
public:
  DataScheduler();

  /**
   * Initialize scheduler with queue sizes
   */
  bool begin(size_t criticalQueueSize = 10, size_t highQueueSize = 10, size_t normalQueueSize = 20);

  /**
   * Enqueue data for transmission
   * @return true if packet was queued, false if queue is full
   */
  bool enqueueAlert(const char* alertMessage);
  bool enqueueHeartRate(uint8_t hr);
  bool enqueueAudio(const uint8_t* audioData, size_t size);

  /**
   * Get next packet to transmit (priority-ordered)
   * @param packet Output parameter for next packet
   * @param timeoutMs Maximum time to wait for a packet (0 = no wait)
   * @return true if packet was retrieved, false if no packets available
   */
  bool getNextPacket(DataPacket& packet, uint32_t timeoutMs = 0);

  /**
   * Check if any packets are available
   */
  bool hasPackets();

  /**
   * Get queue statistics
   */
  size_t getCriticalQueueCount();
  size_t getHighQueueCount();
  size_t getNormalQueueCount();

  /**
   * Clear all queues (use sparingly, e.g., on disconnect)
   */
  void clearAllQueues();

  /**
   * Bandwidth management - limit audio transmission rate
   * @param maxAudioPacketsPerSecond Maximum audio packets to transmit per second
   */
  void setAudioRateLimit(uint16_t maxAudioPacketsPerSecond);

  /**
   * Check if audio transmission should be throttled
   * @return true if we can send audio now, false if rate-limited
   */
  bool canSendAudio();

  /**
   * Print queue statistics (for debugging)
   */
  void printStatistics();

private:
  // FreeRTOS queue handles
  QueueHandle_t criticalQueue;
  QueueHandle_t highQueue;
  QueueHandle_t normalQueue;

  // Audio rate limiting
  uint16_t audioRateLimit;           // Max audio packets/second
  uint32_t lastAudioTransmitTime;    // millis() of last audio packet
  uint16_t audioPacketsThisSecond;   // Counter for current second
  uint32_t audioRateLimitWindowStart; // Start of current 1-second window

  // Statistics
  uint32_t droppedCriticalPackets;
  uint32_t droppedHighPackets;
  uint32_t droppedNormalPackets;

  bool initialized;
};

#endif // DATA_SCHEDULER_H
