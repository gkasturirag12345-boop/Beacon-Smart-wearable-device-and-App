/*
 * Configuration Header for ESP32-C3 BEACON Device
 * All constants, thresholds, and UUIDs centralized here
 */

#ifndef CONFIG_H
#define CONFIG_H

// ============================================================================
// HEART RATE THRESHOLDS
// ============================================================================
#define HR_NO_BEAT_TIMEOUT 5000  // ms - trigger heart stop alert
#define HR_SAMPLE_INTERVAL 50    // ms - heart rate sampling rate
#define HR_AVERAGE_SIZE 4        // number of beats to average
#define HR_UPDATE_INTERVAL 1000  // ms - transmit heart rate every 1 second (bandwidth optimization)

// ============================================================================
// FALL DETECTION THRESHOLDS
// ============================================================================
#define FALL_ACCEL_THRESHOLD 24.525  // m/s² (~2.5g spike threshold)
#define FALL_MOTION_THRESHOLD 1.962  // m/s² (~0.2g near-zero motion)
#define FALL_STATIONARY_TIME 2000    // ms - stationary duration after spike
#define IMU_UPDATE_INTERVAL 50       // ms - IMU reading interval

// ============================================================================
// PROXIMITY/WEAR DETECTION
// ============================================================================
#define PROXIMITY_WORN_THRESHOLD 1000  // proximity value below = worn
#define PROXIMITY_CHECK_INTERVAL 5000  // ms - check interval
#define STARTUP_GRACE_PERIOD 30000     // ms - delay before enabling sleep modes

// ============================================================================
// MAX30105 IR-BASED WEAR DETECTION
// ============================================================================
#define IR_WEAR_THRESHOLD_HIGH 10000  // IR value above = definitely worn
#define IR_WEAR_THRESHOLD_LOW 5000    // IR value below = definitely not worn
#define IR_CHECK_INTERVAL 2000        // ms - IR wear check interval
#define NOT_WORN_TIMEOUT 60000        // ms - 60 seconds before entering low power

// ============================================================================
// POWER MANAGEMENT
// ============================================================================
#define IDLE_TIMEOUT_DEEP_SLEEP 30000  // ms - deep sleep if no BLE and idle
#define LIGHT_SLEEP_DURATION 5000000   // us - 5 seconds
#define WAKE_CHECK_INTERVAL 10000000   // us - 10 seconds for periodic wake
#define MOTION_WAKE_THRESHOLD 0.3      // G force to wake from sleep

// ============================================================================
// I2C CONFIGURATION
// ============================================================================
#define I2C_SDA_PIN 8   // ESP32-C3 default SDA pin
#define I2C_SCL_PIN 9   // ESP32-C3 default SCL pin

// Expected I2C addresses
#define MAX30105_I2C_ADDR 0x57  // Heart rate sensor
#define BNO085_I2C_ADDR_1 0x4A  // IMU (default)
#define BNO085_I2C_ADDR_2 0x4B  // IMU (alternate)
#define VCNL4040_I2C_ADDR 0x60  // Proximity sensor

// ============================================================================
// BUTTON CONFIGURATION
// ============================================================================
#define BUTTON_PIN 3             // GPIO pin for alert button
#define DEBOUNCE_DELAY 50         // ms - button debounce time
#define DOUBLE_PRESS_WINDOW 1000  // ms - time window for double press detection

// ============================================================================
// I2S MICROPHONE CONFIGURATION
// ============================================================================
#define I2S_WS_PIN GPIO_NUM_7   // Word Select (LRCLK)
#define I2S_SCK_PIN GPIO_NUM_5  // Bit Clock (BCLK)
#define I2S_SD_PIN GPIO_NUM_6   // Serial Data (DOUT)

// ============================================================================
// AUDIO COMPRESSION & BANDWIDTH OPTIMIZATION
// ============================================================================
#define AUDIO_ENABLE_ADPCM true           // Enable ADPCM compression (4:1 ratio)
#define AUDIO_ADPCM_BUFFER_SIZE 256       // Samples to compress per chunk (128 bytes output)
#define AUDIO_BASE_SAMPLE_RATE 16000      // Base sample rate (16 kHz)
#define AUDIO_LOW_POWER_SAMPLE_RATE 8000  // Low power sample rate (8 kHz when idle)
#define AUDIO_VAD_THRESHOLD 1500          // Voice Activity Detection RMS threshold
#define AUDIO_ADAPTIVE_RATE true          // Enable adaptive sample rate based on VAD

// Audio transmission rate limiting (packets per second)
#define AUDIO_MAX_PACKETS_PER_SEC_HIGH 30  // High activity mode (with voice)
#define AUDIO_MAX_PACKETS_PER_SEC_LOW 15   // Low activity mode (no voice)

// ============================================================================
// BLE CONNECTION PARAMETERS (Bandwidth Optimization)
// ============================================================================
#define BLE_CONN_INTERVAL_MIN 12   // 15ms (12 * 1.25ms) - faster connection interval
#define BLE_CONN_INTERVAL_MAX 12   // 15ms (12 * 1.25ms) - fixed interval for predictability
#define BLE_CONN_LATENCY 0         // No latency - immediate response
#define BLE_SUPERVISION_TIMEOUT 500 // 5000ms (500 * 10ms) - prevent premature disconnect
#define BLE_REQUESTED_MTU 247      // Maximum BLE MTU (244 usable bytes + 3 header)

// ============================================================================
// BLE UUIDs - Unified Stage 1 Specification
// ============================================================================
#define SERVICE_UUID "12345678-9012-3456-7890-1234567890AB"       // Main service
#define HR_CHAR_UUID "12345678-9012-3456-7890-1234567890AC"       // Heart Rate
#define ALERT_CHAR_UUID "12345678-9012-3456-7890-1234567890AD"    // AlertStatus
#define CONTROL_CHAR_UUID "12345678-9012-3456-7890-1234567890AE"  // ControlCommand
#define AUDIO_CHAR_UUID "12345678-9012-3456-7890-1234567890AF"    // Audio Stream (16kHz, 16-bit)


// ============================================================================
// POWER STATE MACHINE
// ============================================================================
enum PowerState {
  ACTIVE,            // Normal operation - all sensors active
  WORN_CHECK,        // Checking if device is still worn (countdown phase)
  TRANSITION_SLEEP,  // About to enter sleep (warning phase)
  LIGHT_SLEEP,       // Not worn - periodic wake-ups to check
  DEEP_SLEEP         // No BLE + idle - deep sleep mode
};

#endif // CONFIG_H
