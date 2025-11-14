/*
 * Audio Detector for ESP32-C3 BEACON Device
 * I2S Microphone Support with Sound Event Detection
 *
 * Features:
 * - I2S MEMS microphone input (16kHz, 16-bit)
 * - DMA-based continuous sampling
 * - FFT frequency analysis (128 samples)
 * - Sound event detection (fall thud, distress sounds)
 * - Low-latency callback system
 *
 * Hardware:
 * - I2S MEMS microphone (e.g., INMP441, ICS-43434)
 * - Connections:
 *   - WS (Word Select / LRCLK): GPIO 4
 *   - SCK (Bit Clock / BCLK): GPIO 5
 *   - SD (Serial Data / DOUT): GPIO 6
 *   - VDD: 3.3V, GND: GND
 */

#ifndef AUDIO_DETECTOR_H
#define AUDIO_DETECTOR_H

#include <Arduino.h>
#include <driver/i2s.h>
#include "ADPCMCodec.h"     // ADPCM compression
#include "DataScheduler.h"  // Priority-based BLE transmission

// ============================================================================
// I2S CONFIGURATION
// ============================================================================

#define I2S_PORT I2S_NUM_0
#define I2S_SAMPLE_RATE 16000  // 16kHz sample rate
#define I2S_BITS_PER_SAMPLE 16
#define I2S_CHANNELS 1  // Mono
#define I2S_DMA_BUF_COUNT 4
#define I2S_DMA_BUF_LEN 256  // 256 samples per buffer

// I2S Pin Configuration (ESP32-C3 CodeCell) - Match Config.h
// Note: Config.h defines these pins, using them here for consistency

// ============================================================================
// AUDIO PROCESSING CONFIGURATION
// ============================================================================

#define FFT_SIZE 128  // FFT window size (not used - streaming only)
#define AUDIO_UPDATE_INTERVAL 100  // ms - not used (continuous streaming)

// Sound event detection thresholds
#define THUD_FREQ_LOW 50        // Hz - low frequency for impact sounds
#define THUD_FREQ_HIGH 500      // Hz - high frequency for impact sounds
#define THUD_AMPLITUDE_THRESHOLD 8000  // Amplitude threshold for fall detection

#define DISTRESS_FREQ_LOW 300   // Hz - human voice low range
#define DISTRESS_FREQ_HIGH 3000 // Hz - human voice high range
#define DISTRESS_AMPLITUDE_THRESHOLD 5000  // Amplitude for distress sounds

#define NOISE_FLOOR 1000  // Minimum amplitude to consider (ignore background noise)

// ============================================================================
// AUDIO EVENT TYPES
// ============================================================================

enum AudioEventType {
  AUDIO_NONE,
  AUDIO_LOUD_THUD,      // Sudden impact (fall-related)
  AUDIO_DISTRESS_SOUND, // Cry, scream, distress vocalization
  AUDIO_SUSTAINED_LOUD  // Continuous loud sound
};

// ============================================================================
// AUDIO DETECTOR CLASS
// ============================================================================

class AudioDetector {
public:
  AudioDetector();

  // Initialization
  bool begin();
  void end();

  // Audio processing
  void update();

  // BLE audio streaming
  void setDataScheduler(DataScheduler* scheduler);
  void enableStreaming(bool enable);
  bool isStreaming() { return streamingEnabled; }

  // Adaptive sample rate based on voice activity
  void setAdaptiveRate(bool enable);
  bool isVoiceActive() { return voiceActive; }

  // Event callbacks
  void setThudCallback(void (*callback)());
  void setDistressCallback(void (*callback)());

  // Status
  bool isInitialized() { return initialized; }
  int16_t getCurrentAmplitude() { return currentAmplitude; }
  AudioEventType getLastEvent() { return lastEvent; }

private:
  bool initialized;
  unsigned long lastUpdateTime;

  // Audio buffers
  int16_t audioBuffer[FFT_SIZE];
  size_t audioBufferIndex;

  // Audio analysis results
  int16_t currentAmplitude;
  AudioEventType lastEvent;
  unsigned long lastEventTime;

  // BLE streaming with compression
  DataScheduler* dataScheduler;
  bool streamingEnabled;
  bool adaptiveRateEnabled;
  bool voiceActive;

  // ADPCM compression
  ADPCMCodec adpcmCodec;
  static const size_t STREAM_BUFFER_SIZE = 256;  // 256 samples for compression
  int16_t streamBuffer[STREAM_BUFFER_SIZE];
  size_t streamBufferIndex;
  uint8_t compressedBuffer[128];  // ADPCM output (4:1 compression)

  // Voice activity detection
  uint32_t lastVADCheck;
  uint32_t voiceActiveStartTime;
  static const uint32_t VAD_CHECK_INTERVAL = 100;  // Check every 100ms

  // Callbacks
  void (*thudCallback)();
  void (*distressCallback)();

  // I2S functions
  bool initI2S();
  void deinitI2S();

  // Audio processing
  void readAudioSamples();
  void processAudio();
  int16_t calculateAmplitude(int16_t* samples, size_t count);
  bool detectThud(int16_t* samples, size_t count);
  bool detectDistress(int16_t* samples, size_t count);

  // Simple frequency analysis (peak detection in frequency bands)
  int16_t getFrequencyBandEnergy(int16_t* samples, size_t count, int freqLow, int freqHigh);
};

#endif // AUDIO_DETECTOR_H
