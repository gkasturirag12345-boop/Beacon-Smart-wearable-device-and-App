/*
 * IMA ADPCM Codec for ESP32-C3
 * Provides 4:1 compression for 16-bit PCM audio
 *
 * IMA ADPCM reduces 16-bit samples to 4-bit codes
 * Bandwidth reduction: 256 kbps -> 64 kbps (16 kHz mono)
 *
 * Algorithm: IMA/DVI ADPCM (Intel/DVI specification)
 * Reference: IMA Digital Audio Focus and Technical Working Groups
 */

#ifndef ADPCM_CODEC_H
#define ADPCM_CODEC_H

#include <Arduino.h>

// ============================================================================
// ADPCM ENCODER STATE
// ============================================================================

struct ADPCMState {
  int16_t predictedSample;  // Predicted sample value
  int16_t stepIndex;        // Current step index (0-88)

  ADPCMState() : predictedSample(0), stepIndex(0) {}

  void reset() {
    predictedSample = 0;
    stepIndex = 0;
  }
};

// ============================================================================
// ADPCM CODEC CLASS
// ============================================================================

class ADPCMCodec {
public:
  ADPCMCodec();

  // Encoder functions
  void resetEncoder();

  /**
   * Encode 16-bit PCM samples to 4-bit ADPCM codes
   * @param pcmSamples Input PCM samples (16-bit signed)
   * @param numSamples Number of samples to encode
   * @param adpcmOutput Output buffer for ADPCM codes (4 bits/sample, packed into bytes)
   * @return Number of bytes written to adpcmOutput (numSamples/2)
   */
  size_t encode(const int16_t* pcmSamples, size_t numSamples, uint8_t* adpcmOutput);

  /**
   * Get current encoder state (for header transmission)
   */
  void getState(int16_t& predictedSample, int16_t& stepIndex);

  /**
   * Set encoder state (for resuming from header)
   */
  void setState(int16_t predictedSample, int16_t stepIndex);

private:
  ADPCMState encoderState;

  // Core ADPCM encoding algorithm
  uint8_t encodeSample(int16_t sample);

  // IMA ADPCM step size table (89 entries, index 0-88)
  static const int16_t stepSizeTable[89];

  // IMA ADPCM step index adjustment table
  static const int8_t indexTable[16];
};

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Simple Voice Activity Detection (VAD)
 * Returns true if audio energy exceeds threshold
 */
bool detectVoiceActivity(const int16_t* samples, size_t count, int16_t threshold = 1500);

/**
 * Calculate RMS amplitude of audio samples
 */
int16_t calculateRMS(const int16_t* samples, size_t count);

#endif // ADPCM_CODEC_H
