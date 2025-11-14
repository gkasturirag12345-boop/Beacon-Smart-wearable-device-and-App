/*
 * Data Scheduler Implementation
 * Priority-based BLE transmission queue management
 */

#include "DataScheduler.h"

// ============================================================================
// CONSTRUCTOR
// ============================================================================

DataScheduler::DataScheduler()
  : criticalQueue(nullptr),
    highQueue(nullptr),
    normalQueue(nullptr),
    audioRateLimit(30),  // Default: 30 audio packets/second (adaptive)
    lastAudioTransmitTime(0),
    audioPacketsThisSecond(0),
    audioRateLimitWindowStart(0),
    droppedCriticalPackets(0),
    droppedHighPackets(0),
    droppedNormalPackets(0),
    initialized(false) {
}

// ============================================================================
// INITIALIZATION
// ============================================================================

bool DataScheduler::begin(size_t criticalQueueSize, size_t highQueueSize, size_t normalQueueSize) {
  Serial.println(F("[DataScheduler] Initializing priority queues..."));

  // Create FreeRTOS queues for each priority level
  criticalQueue = xQueueCreate(criticalQueueSize, sizeof(DataPacket));
  if (criticalQueue == nullptr) {
    Serial.println(F("[DataScheduler] ERROR: Failed to create critical queue"));
    return false;
  }

  highQueue = xQueueCreate(highQueueSize, sizeof(DataPacket));
  if (highQueue == nullptr) {
    Serial.println(F("[DataScheduler] ERROR: Failed to create high priority queue"));
    vQueueDelete(criticalQueue);
    return false;
  }

  normalQueue = xQueueCreate(normalQueueSize, sizeof(DataPacket));
  if (normalQueue == nullptr) {
    Serial.println(F("[DataScheduler] ERROR: Failed to create normal priority queue"));
    vQueueDelete(criticalQueue);
    vQueueDelete(highQueue);
    return false;
  }

  initialized = true;

  Serial.print(F("[DataScheduler] Queue sizes - Critical: "));
  Serial.print(criticalQueueSize);
  Serial.print(F(", High: "));
  Serial.print(highQueueSize);
  Serial.print(F(", Normal: "));
  Serial.println(normalQueueSize);
  Serial.println(F("[DataScheduler] Initialized successfully"));

  return true;
}

// ============================================================================
// ENQUEUE FUNCTIONS
// ============================================================================

bool DataScheduler::enqueueAlert(const char* alertMessage) {
  if (!initialized) {
    Serial.println(F("[DataScheduler] ERROR: Not initialized!"));
    return false;
  }

  DataPacket packet;
  packet.priority = PRIORITY_CRITICAL;
  packet.type = DATA_ALERT;
  packet.timestamp = millis();
  packet.dataSize = min(strlen(alertMessage), (size_t)(MAX_ALERT_SIZE - 1));
  memcpy(packet.data, alertMessage, packet.dataSize);
  packet.data[packet.dataSize] = '\0';  // Null-terminate

  if (xQueueSend(criticalQueue, &packet, 0) != pdTRUE) {
    droppedCriticalPackets++;
    Serial.println(F("[DataScheduler] WARNING: Critical queue full - alert dropped!"));
    return false;
  }

  Serial.print(F("[DataScheduler] ✅ Enqueued ALERT: "));
  Serial.println(alertMessage);
  Serial.print(F("[DataScheduler] Queue sizes - Critical: "));
  Serial.print(getCriticalQueueCount());
  Serial.print(F(", High: "));
  Serial.print(getHighQueueCount());
  Serial.print(F(", Normal: "));
  Serial.println(getNormalQueueCount());

  return true;
}

bool DataScheduler::enqueueHeartRate(uint8_t hr) {
  if (!initialized) return false;

  DataPacket packet;
  packet.priority = PRIORITY_HIGH;
  packet.type = DATA_HEART_RATE;
  packet.timestamp = millis();
  packet.dataSize = 1;
  packet.data[0] = hr;

  if (xQueueSend(highQueue, &packet, 0) != pdTRUE) {
    droppedHighPackets++;
    Serial.println(F("[DataScheduler] WARNING: High priority queue full - HR dropped"));
    return false;
  }

  Serial.print(F("[DataScheduler] ✅ Enqueued HEART RATE: "));
  Serial.print(hr);
  Serial.print(F(" BPM (Queue: "));
  Serial.print(getHighQueueCount());
  Serial.println(F(" items)"));

  return true;
}

bool DataScheduler::enqueueAudio(const uint8_t* audioData, size_t size) {
  if (!initialized) return false;

  // Check rate limiting
  if (!canSendAudio()) {
    // Drop audio packet (not critical data)
    return false;
  }

  DataPacket packet;
  packet.priority = PRIORITY_NORMAL;
  packet.type = DATA_AUDIO;
  packet.timestamp = millis();
  packet.dataSize = min(size, (size_t)MAX_AUDIO_SIZE);
  memcpy(packet.data, audioData, packet.dataSize);

  if (xQueueSend(normalQueue, &packet, 0) != pdTRUE) {
    droppedNormalPackets++;
    // Don't log every dropped audio packet (too verbose)
    return false;
  }

  // Update rate limiting counters
  lastAudioTransmitTime = millis();
  audioPacketsThisSecond++;

  return true;
}

// ============================================================================
// DEQUEUE FUNCTIONS
// ============================================================================

bool DataScheduler::getNextPacket(DataPacket& packet, uint32_t timeoutMs) {
  if (!initialized) return false;

  TickType_t timeout = (timeoutMs == 0) ? 0 : pdMS_TO_TICKS(timeoutMs);

  // Priority 1: Check critical queue first (alerts)
  if (xQueueReceive(criticalQueue, &packet, 0) == pdTRUE) {
    return true;
  }

  // Priority 2: Check high priority queue (heart rate)
  if (xQueueReceive(highQueue, &packet, 0) == pdTRUE) {
    return true;
  }

  // Priority 3: Check normal priority queue (audio)
  if (xQueueReceive(normalQueue, &packet, timeout) == pdTRUE) {
    return true;
  }

  return false;
}

bool DataScheduler::hasPackets() {
  if (!initialized) return false;

  return (uxQueueMessagesWaiting(criticalQueue) > 0 ||
          uxQueueMessagesWaiting(highQueue) > 0 ||
          uxQueueMessagesWaiting(normalQueue) > 0);
}

// ============================================================================
// QUEUE STATISTICS
// ============================================================================

size_t DataScheduler::getCriticalQueueCount() {
  if (!initialized) return 0;
  return uxQueueMessagesWaiting(criticalQueue);
}

size_t DataScheduler::getHighQueueCount() {
  if (!initialized) return 0;
  return uxQueueMessagesWaiting(highQueue);
}

size_t DataScheduler::getNormalQueueCount() {
  if (!initialized) return 0;
  return uxQueueMessagesWaiting(normalQueue);
}

void DataScheduler::clearAllQueues() {
  if (!initialized) return;

  xQueueReset(criticalQueue);
  xQueueReset(highQueue);
  xQueueReset(normalQueue);

  Serial.println(F("[DataScheduler] All queues cleared"));
}

// ============================================================================
// AUDIO RATE LIMITING
// ============================================================================

void DataScheduler::setAudioRateLimit(uint16_t maxAudioPacketsPerSecond) {
  audioRateLimit = maxAudioPacketsPerSecond;
  Serial.print(F("[DataScheduler] Audio rate limit set to "));
  Serial.print(audioRateLimit);
  Serial.println(F(" packets/second"));
}

bool DataScheduler::canSendAudio() {
  uint32_t currentTime = millis();

  // Reset counter every second
  if (currentTime - audioRateLimitWindowStart >= 1000) {
    audioRateLimitWindowStart = currentTime;
    audioPacketsThisSecond = 0;
  }

  // Check if we're within rate limit
  return (audioPacketsThisSecond < audioRateLimit);
}

void DataScheduler::printStatistics() {
  if (!initialized) return;

  Serial.println(F("========================================"));
  Serial.println(F("[DataScheduler] Queue Statistics"));
  Serial.println(F("========================================"));

  Serial.print(F("  Critical Queue: "));
  Serial.print(getCriticalQueueCount());
  Serial.print(F(" / 10 (Dropped: "));
  Serial.print(droppedCriticalPackets);
  Serial.println(F(")"));

  Serial.print(F("  High Queue:     "));
  Serial.print(getHighQueueCount());
  Serial.print(F(" / 10 (Dropped: "));
  Serial.print(droppedHighPackets);
  Serial.println(F(")"));

  Serial.print(F("  Normal Queue:   "));
  Serial.print(getNormalQueueCount());
  Serial.print(F(" / 20 (Dropped: "));
  Serial.print(droppedNormalPackets);
  Serial.println(F(")"));

  Serial.print(F("  Audio Rate: "));
  Serial.print(audioPacketsThisSecond);
  Serial.print(F(" / "));
  Serial.print(audioRateLimit);
  Serial.println(F(" pkt/s"));

  Serial.println(F("========================================"));
}
