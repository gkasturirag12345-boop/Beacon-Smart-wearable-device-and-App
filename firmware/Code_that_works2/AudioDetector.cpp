/*
 * Audio Detector Implementation
 * I2S microphone processing with ADPCM compression and sound event detection
 */

#include "AudioDetector.h"
#include "Config.h"

// ============================================================================
// CONSTRUCTOR
// ============================================================================

AudioDetector::AudioDetector() {
  initialized = false;
  lastUpdateTime = 0;
  audioBufferIndex = 0;
  currentAmplitude = 0;
  lastEvent = AUDIO_NONE;
  lastEventTime = 0;
  thudCallback = nullptr;
  distressCallback = nullptr;
  dataScheduler = nullptr;
  streamingEnabled = false;
  adaptiveRateEnabled = AUDIO_ADAPTIVE_RATE;
  voiceActive = false;
  streamBufferIndex = 0;
  lastVADCheck = 0;
  voiceActiveStartTime = 0;

  memset(audioBuffer, 0, sizeof(audioBuffer));
  memset(streamBuffer, 0, sizeof(streamBuffer));
  memset(compressedBuffer, 0, sizeof(compressedBuffer));
}

// ============================================================================
// INITIALIZATION
// ============================================================================

bool AudioDetector::begin() {
  Serial.println(F("[Audio] Initializing I2S microphone..."));

  if (!initI2S()) {
    Serial.println(F("[Audio] ERROR: I2S init failed"));
    return false;
  }

  initialized = true;
  lastUpdateTime = millis();

  // Initialize ADPCM encoder
  adpcmCodec.resetEncoder();

  Serial.println(F("[Audio] I2S microphone ready"));
  Serial.println(F("[Audio] ADPCM compression enabled (4:1 ratio)"));
  if (adaptiveRateEnabled) {
    Serial.println(F("[Audio] Adaptive sample rate enabled (8-16 kHz)"));
  }
  return true;
}

void AudioDetector::end() {
  if (!initialized) return;

  deinitI2S();
  initialized = false;

  Serial.println(F("[Audio] Stopped"));
}

// ============================================================================
// I2S DRIVER INITIALIZATION
// ============================================================================

bool AudioDetector::initI2S() {
  i2s_config_t i2s_config = {
    .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX),
    .sample_rate = I2S_SAMPLE_RATE,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
    .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
    .communication_format = I2S_COMM_FORMAT_STAND_I2S,
    .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count = I2S_DMA_BUF_COUNT,
    .dma_buf_len = I2S_DMA_BUF_LEN,
    .use_apll = false,
    .tx_desc_auto_clear = false,
    .fixed_mclk = 0
  };

  i2s_pin_config_t pin_config = {
    .bck_io_num = I2S_SCK_PIN,
    .ws_io_num = I2S_WS_PIN,
    .data_out_num = I2S_PIN_NO_CHANGE,
    .data_in_num = I2S_SD_PIN
  };

  esp_err_t err = i2s_driver_install(I2S_PORT, &i2s_config, 0, NULL);
  if (err != ESP_OK) {
    Serial.print(F("[Audio] Driver install failed: "));
    Serial.println(err);
    return false;
  }

  err = i2s_set_pin(I2S_PORT, &pin_config);
  if (err != ESP_OK) {
    Serial.print(F("[Audio] Pin config failed: "));
    Serial.println(err);
    i2s_driver_uninstall(I2S_PORT);
    return false;
  }

  // Start I2S
  i2s_zero_dma_buffer(I2S_PORT);

  return true;
}

void AudioDetector::deinitI2S() {
  i2s_driver_uninstall(I2S_PORT);
}

// ============================================================================
// MAIN UPDATE LOOP
// ============================================================================

void AudioDetector::update() {
  if (!initialized) return;

  // Only read and stream audio - no local processing
  // All ML inference happens on iPhone via TensorFlow Lite
  readAudioSamples();

  // Note: Local audio processing (processAudio) is disabled to prevent
  // I2S DMA from blocking I2C transactions. Audio is streamed to iPhone
  // for SOS detection via TensorFlow Lite model.
}

// ============================================================================
// AUDIO SAMPLE READING
// ============================================================================

void AudioDetector::readAudioSamples() {
  size_t bytesRead = 0;
  int16_t samples[32];  // Read in small chunks

  // Read samples from I2S DMA
  esp_err_t err = i2s_read(I2S_PORT, samples, sizeof(samples), &bytesRead, pdMS_TO_TICKS(10));

  if (err != ESP_OK || bytesRead == 0) {
    return;
  }

  size_t samplesRead = bytesRead / sizeof(int16_t);

  // Copy to audio buffer for local analysis
  for (size_t i = 0; i < samplesRead && audioBufferIndex < FFT_SIZE; i++) {
    audioBuffer[audioBufferIndex++] = samples[i];
  }

  // Stream to BLE with ADPCM compression if enabled
  if (streamingEnabled && dataScheduler) {
    for (size_t i = 0; i < samplesRead; i++) {
      streamBuffer[streamBufferIndex++] = samples[i];

      // When stream buffer is full, compress and send via DataScheduler
      if (streamBufferIndex >= STREAM_BUFFER_SIZE) {
        // Perform Voice Activity Detection
        uint32_t currentTime = millis();
        if (currentTime - lastVADCheck >= VAD_CHECK_INTERVAL) {
          lastVADCheck = currentTime;
          voiceActive = detectVoiceActivity(streamBuffer, STREAM_BUFFER_SIZE, AUDIO_VAD_THRESHOLD);

          // Adjust audio packet rate based on voice activity (only on state change)
          if (voiceActive) {
            if (voiceActiveStartTime == 0) {  // STATE CHANGE: inactive → active
              voiceActiveStartTime = currentTime;
              dataScheduler->setAudioRateLimit(AUDIO_MAX_PACKETS_PER_SEC_HIGH);
              Serial.println(F("[Audio] Voice activity detected - increasing rate to 30 pkt/s"));
            }
          } else {
            if (voiceActiveStartTime != 0) {  // STATE CHANGE: active → inactive
              voiceActiveStartTime = 0;
              dataScheduler->setAudioRateLimit(AUDIO_MAX_PACKETS_PER_SEC_LOW);
              Serial.println(F("[Audio] Voice inactive - reducing rate to 15 pkt/s"));
            }
          }
        }

        // Compress audio with ADPCM (4:1 compression)
        size_t compressedSize = adpcmCodec.encode(streamBuffer, STREAM_BUFFER_SIZE, compressedBuffer);

        // Send compressed audio via DataScheduler (priority-based)
        dataScheduler->enqueueAudio(compressedBuffer, compressedSize);

        streamBufferIndex = 0;
      }
    }
  }
}

// ============================================================================
// AUDIO PROCESSING
// ============================================================================

void AudioDetector::processAudio() {
  // Calculate overall amplitude (RMS)
  currentAmplitude = calculateAmplitude(audioBuffer, FFT_SIZE);

  // Ignore very quiet sounds (noise floor)
  if (currentAmplitude < NOISE_FLOOR) {
    lastEvent = AUDIO_NONE;
    return;
  }

  // Detect thud (low-frequency impact)
  if (detectThud(audioBuffer, FFT_SIZE)) {
    lastEvent = AUDIO_LOUD_THUD;
    lastEventTime = millis();

    Serial.print(F("[Audio] THUD detected - amplitude: "));
    Serial.println(currentAmplitude);

    if (thudCallback) {
      thudCallback();
    }
    return;
  }

  // Detect distress sounds (mid-frequency sustained)
  if (detectDistress(audioBuffer, FFT_SIZE)) {
    lastEvent = AUDIO_DISTRESS_SOUND;
    lastEventTime = millis();

    Serial.print(F("[Audio] Distress sound - amplitude: "));
    Serial.println(currentAmplitude);

    if (distressCallback) {
      distressCallback();
    }
    return;
  }

  lastEvent = AUDIO_NONE;
}

// ============================================================================
// AUDIO ANALYSIS FUNCTIONS
// ============================================================================

int16_t AudioDetector::calculateAmplitude(int16_t* samples, size_t count) {
  int32_t sum = 0;

  for (size_t i = 0; i < count; i++) {
    int32_t sample = samples[i];
    sum += (sample * sample);
  }

  // RMS amplitude
  return (int16_t)sqrt(sum / count);
}

bool AudioDetector::detectThud(int16_t* samples, size_t count) {
  // Get energy in low-frequency band (50-500 Hz)
  int16_t lowFreqEnergy = getFrequencyBandEnergy(samples, count, THUD_FREQ_LOW, THUD_FREQ_HIGH);

  // Thud: high energy in low frequencies, sudden spike
  return (lowFreqEnergy > THUD_AMPLITUDE_THRESHOLD);
}

bool AudioDetector::detectDistress(int16_t* samples, size_t count) {
  // Get energy in voice frequency band (300-3000 Hz)
  int16_t voiceEnergy = getFrequencyBandEnergy(samples, count, DISTRESS_FREQ_LOW, DISTRESS_FREQ_HIGH);

  // Distress: sustained energy in voice range
  return (voiceEnergy > DISTRESS_AMPLITUDE_THRESHOLD);
}

int16_t AudioDetector::getFrequencyBandEnergy(int16_t* samples, size_t count, int freqLow, int freqHigh) {
  // Simplified frequency band analysis without full FFT
  // Uses time-domain autocorrelation to estimate dominant frequency

  int32_t energy = 0;
  int lagMin = I2S_SAMPLE_RATE / freqHigh;  // Lag for high freq
  int lagMax = I2S_SAMPLE_RATE / freqLow;   // Lag for low freq

  // Autocorrelation to detect periodicity in target frequency range
  for (int lag = lagMin; lag < lagMax && lag < (int)count / 2; lag++) {
    int32_t correlation = 0;

    for (size_t i = 0; i < count - lag; i++) {
      correlation += (int32_t)samples[i] * samples[i + lag];
    }

    if (correlation > energy) {
      energy = correlation;
    }
  }

  // Normalize by sample count
  return (int16_t)(energy / (count * 100));
}

// ============================================================================
// BLE STREAMING CONFIGURATION
// ============================================================================

void AudioDetector::setDataScheduler(DataScheduler* scheduler) {
  dataScheduler = scheduler;
  if (scheduler) {
    // Initialize with low packet rate (will adjust based on VAD)
    scheduler->setAudioRateLimit(AUDIO_MAX_PACKETS_PER_SEC_LOW);
  }
}

void AudioDetector::enableStreaming(bool enable) {
  streamingEnabled = enable;
  if (enable) {
    Serial.println(F("[Audio] BLE streaming enabled with ADPCM compression"));
  } else {
    Serial.println(F("[Audio] BLE streaming disabled"));
  }
}

void AudioDetector::setAdaptiveRate(bool enable) {
  adaptiveRateEnabled = enable;
  if (enable) {
    Serial.println(F("[Audio] Adaptive rate enabled (VAD-based)"));
  } else {
    Serial.println(F("[Audio] Adaptive rate disabled"));
  }
}

// ============================================================================
// CALLBACK REGISTRATION
// ============================================================================

void AudioDetector::setThudCallback(void (*callback)()) {
  thudCallback = callback;
}

void AudioDetector::setDistressCallback(void (*callback)()) {
  distressCallback = callback;
}
