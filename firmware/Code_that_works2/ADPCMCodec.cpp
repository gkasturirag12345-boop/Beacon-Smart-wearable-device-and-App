/*
 * IMA ADPCM Codec Implementation
 * 4:1 compression for 16-bit PCM audio
 */

#include "ADPCMCodec.h"

// ============================================================================
// IMA ADPCM TABLES
// ============================================================================

// Step size table (89 entries, indexed 0-88)
const int16_t ADPCMCodec::stepSizeTable[89] = {
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17,
    19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
    50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
    130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
    337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
    876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
    2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
    5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
    15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
};

// Step index adjustment table
const int8_t ADPCMCodec::indexTable[16] = {
    -1, -1, -1, -1, 2, 4, 6, 8,
    -1, -1, -1, -1, 2, 4, 6, 8
};

// ============================================================================
// CONSTRUCTOR
// ============================================================================

ADPCMCodec::ADPCMCodec() {
  resetEncoder();
}

void ADPCMCodec::resetEncoder() {
  encoderState.reset();
}

// ============================================================================
// ENCODER FUNCTIONS
// ============================================================================

size_t ADPCMCodec::encode(const int16_t* pcmSamples, size_t numSamples, uint8_t* adpcmOutput) {
  size_t outputIndex = 0;
  uint8_t packedByte = 0;

  for (size_t i = 0; i < numSamples; i++) {
    uint8_t adpcmCode = encodeSample(pcmSamples[i]);

    // Pack two 4-bit ADPCM codes into one byte
    if (i % 2 == 0) {
      // First sample: store in lower nibble
      packedByte = adpcmCode & 0x0F;
    } else {
      // Second sample: store in upper nibble and write byte
      packedByte |= (adpcmCode << 4);
      adpcmOutput[outputIndex++] = packedByte;
      packedByte = 0;
    }
  }

  // Handle odd number of samples
  if (numSamples % 2 != 0) {
    adpcmOutput[outputIndex++] = packedByte;
  }

  return outputIndex;
}

uint8_t ADPCMCodec::encodeSample(int16_t sample) {
  int16_t diff = sample - encoderState.predictedSample;
  uint8_t code = 0;

  // Store sign bit
  if (diff < 0) {
    code = 8;  // Set bit 3 (sign bit)
    diff = -diff;
  }

  // Quantize the difference using current step size
  int16_t stepSize = stepSizeTable[encoderState.stepIndex];
  int16_t delta = stepSize >> 3;  // Initialize with stepSize/8

  // Bit 2
  if (diff >= stepSize) {
    code |= 4;
    diff -= stepSize;
  }
  stepSize >>= 1;

  // Bit 1
  if (diff >= stepSize) {
    code |= 2;
    diff -= stepSize;
  }
  stepSize >>= 1;

  // Bit 0
  if (diff >= stepSize) {
    code |= 1;
  }

  // Reconstruct the quantized difference
  stepSize = stepSizeTable[encoderState.stepIndex];
  delta = stepSize >> 3;

  if (code & 4) delta += stepSize;
  if (code & 2) delta += stepSize >> 1;
  if (code & 1) delta += stepSize >> 2;

  // Update predicted sample
  if (code & 8) {
    encoderState.predictedSample -= delta;
  } else {
    encoderState.predictedSample += delta;
  }

  // Clamp predicted sample to 16-bit range
  if (encoderState.predictedSample > 32767) {
    encoderState.predictedSample = 32767;
  } else if (encoderState.predictedSample < -32768) {
    encoderState.predictedSample = -32768;
  }

  // Update step index
  encoderState.stepIndex += indexTable[code];

  // Clamp step index to valid range (0-88)
  if (encoderState.stepIndex < 0) {
    encoderState.stepIndex = 0;
  } else if (encoderState.stepIndex > 88) {
    encoderState.stepIndex = 88;
  }

  return code;
}

void ADPCMCodec::getState(int16_t& predictedSample, int16_t& stepIndex) {
  predictedSample = encoderState.predictedSample;
  stepIndex = encoderState.stepIndex;
}

void ADPCMCodec::setState(int16_t predictedSample, int16_t stepIndex) {
  encoderState.predictedSample = predictedSample;
  encoderState.stepIndex = stepIndex;
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

bool detectVoiceActivity(const int16_t* samples, size_t count, int16_t threshold) {
  int16_t rms = calculateRMS(samples, count);
  return (rms > threshold);
}

int16_t calculateRMS(const int16_t* samples, size_t count) {
  if (count == 0) return 0;

  int32_t sum = 0;
  for (size_t i = 0; i < count; i++) {
    int32_t sample = samples[i];
    sum += (sample * sample);
  }

  // Calculate RMS: sqrt(mean(squares))
  int32_t mean = sum / count;
  return (int16_t)sqrt(mean);
}
