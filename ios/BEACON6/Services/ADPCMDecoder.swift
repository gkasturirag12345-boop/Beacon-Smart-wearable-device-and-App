//
//  ADPCMDecoder.swift
//  BEACON
//
//  IMA ADPCM Decoder for iOS
//  Decodes 4:1 compressed audio from ESP32-C3
//
//  Decodes 4-bit ADPCM codes back to 16-bit PCM samples
//  Compatible with ESP32 ADPCMCodec.cpp implementation
//

import Foundation

/// IMA ADPCM decoder for decompressing audio from ESP32
class ADPCMDecoder {

    // MARK: - ADPCM State

    private struct ADPCMState {
        var predictedSample: Int16 = 0  // Predicted sample value
        var stepIndex: Int16 = 0        // Current step index (0-88)

        mutating func reset() {
            predictedSample = 0
            stepIndex = 0
        }
    }

    private var decoderState = ADPCMState()

    // MARK: - IMA ADPCM Tables

    // Step size table (89 entries, indexed 0-88)
    private static let stepSizeTable: [Int16] = [
        7, 8, 9, 10, 11, 12, 13, 14, 16, 17,
        19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
        50, 55, 60, 66, 73, 80, 88, 97, 107, 118,
        130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
        337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
        876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
        2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358,
        5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
        15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
    ]

    // Step index adjustment table
    private static let indexTable: [Int8] = [
        -1, -1, -1, -1, 2, 4, 6, 8,
        -1, -1, -1, -1, 2, 4, 6, 8
    ]

    // MARK: - Initialization

    init() {
        resetDecoder()
    }

    func resetDecoder() {
        decoderState.reset()
    }

    // MARK: - Decoding Functions

    /// Decode ADPCM data to PCM samples
    /// - Parameter adpcmData: Compressed ADPCM data (4 bits per sample, packed into bytes)
    /// - Returns: Array of 16-bit PCM samples
    func decode(_ adpcmData: Data) -> [Int16] {
        var pcmSamples: [Int16] = []
        pcmSamples.reserveCapacity(adpcmData.count * 2)  // Each byte contains 2 samples

        for byte in adpcmData {
            // Decode lower nibble (first sample)
            let code1 = byte & 0x0F
            let sample1 = decodeSample(code1)
            pcmSamples.append(sample1)

            // Decode upper nibble (second sample)
            let code2 = (byte >> 4) & 0x0F
            let sample2 = decodeSample(code2)
            pcmSamples.append(sample2)
        }

        return pcmSamples
    }

    /// Decode a single 4-bit ADPCM code to a 16-bit PCM sample
    /// - Parameter code: 4-bit ADPCM code
    /// - Returns: 16-bit PCM sample
    private func decodeSample(_ code: UInt8) -> Int16 {
        let stepSize = Self.stepSizeTable[Int(decoderState.stepIndex)]
        var delta = Int16(stepSize) >> 3  // Initialize with stepSize/8

        // Reconstruct quantized difference
        if (code & 4) != 0 {
            delta += stepSize
        }
        if (code & 2) != 0 {
            delta += stepSize >> 1
        }
        if (code & 1) != 0 {
            delta += stepSize >> 2
        }

        // Apply sign bit
        if (code & 8) != 0 {
            decoderState.predictedSample -= delta
        } else {
            decoderState.predictedSample += delta
        }

        // Clamp predicted sample to 16-bit range
        if decoderState.predictedSample > 32767 {
            decoderState.predictedSample = 32767
        } else if decoderState.predictedSample < -32768 {
            decoderState.predictedSample = -32768
        }

        // Update step index
        decoderState.stepIndex += Int16(Self.indexTable[Int(code)])

        // Clamp step index to valid range (0-88)
        if decoderState.stepIndex < 0 {
            decoderState.stepIndex = 0
        } else if decoderState.stepIndex > 88 {
            decoderState.stepIndex = 88
        }

        return decoderState.predictedSample
    }

    // MARK: - State Management

    /// Get current decoder state
    func getState() -> (predictedSample: Int16, stepIndex: Int16) {
        return (decoderState.predictedSample, decoderState.stepIndex)
    }

    /// Set decoder state (for resuming from header)
    func setState(predictedSample: Int16, stepIndex: Int16) {
        decoderState.predictedSample = predictedSample
        decoderState.stepIndex = stepIndex
    }
}

// MARK: - Helper Extensions

extension ADPCMDecoder {
    /// Convert Int16 PCM samples to Float array for audio processing
    /// - Parameter samples: Array of Int16 PCM samples
    /// - Returns: Array of Float samples normalized to [-1.0, 1.0]
    static func int16ToFloat(_ samples: [Int16]) -> [Float] {
        return samples.map { Float($0) / 32768.0 }
    }

    /// Convert Int16 PCM samples to Data for audio playback
    /// - Parameter samples: Array of Int16 PCM samples
    /// - Returns: Data containing raw PCM bytes
    static func int16ToData(_ samples: [Int16]) -> Data {
        var data = Data(capacity: samples.count * 2)
        for sample in samples {
            var value = sample
            withUnsafeBytes(of: &value) { bytes in
                data.append(contentsOf: bytes)
            }
        }
        return data
    }
}
