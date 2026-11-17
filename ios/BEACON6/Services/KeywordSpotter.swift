//
//  KeywordSpotter.swift
//  BEACON6
//
//  Native CoreML + SoundAnalysis SOS Keyword Detection
//  Replaces TensorFlow Lite with Apple's native ML frameworks
//

import Foundation
import AVFoundation
import Combine
import SoundAnalysis

/// Manages real-time audio capture and keyword spotting using CoreML + SoundAnalysis
class KeywordSpotter: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isListening: Bool = false
    @Published var latestDetection: KeywordDetection?
    @Published var averageConfidence: Float = 0.0
    @Published var isModelLoaded: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let alertManager = AlertManager.shared
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var streamAnalyzer: SNAudioStreamAnalyzer?
    private var soundClassifier: SNClassifySoundRequest?

    // Audio configuration
    private let audioQueue = DispatchQueue(label: "com.beacon6.keyword-spotter", qos: .userInitiated)

    // Detection settings - SIMPLIFIED: SOS ≥ 0.6 triggers alert
    private var recentSOSConfidences: [Float] = []
    private let historySize: Int = 3  // For smoothing (optional)
    private let detectionThreshold: Float = 0.6  // USER REQUIREMENT: Alert on SOS ≥ 0.6
    private let confidenceDeltaThreshold: Float = 0.15  // Not used in simplified logic
    private let smoothingEnabled: Bool = false  // DISABLED: Use raw confidence for immediate response

    // External audio support (from ESP32 BLE)
    private var useExternalAudio: Bool = false
    private var externalAudioBuffer: [Int16] = []
    private var externalStreamAnalyzer: SNAudioStreamAnalyzer?

    // Debouncing to prevent multiple rapid alerts
    private var lastSOSDetectionTime: Date?
    private let minDetectionInterval: TimeInterval = 2.0  // 2 seconds between SOS alerts

    // Consecutive detection requirement - REDUCED for faster alerts
    private var consecutiveSOSDetections: Int = 0
    private let requiredConsecutiveDetections: Int = 1  // REDUCED: Single detection is enough (was 2)
    private var recentDetectionTimestamps: [Date] = []
    private let consecutiveTimeWindow: TimeInterval = 1.5  // Faster window (was 2.0)

    // Performance metrics (for monitoring and debugging)
    private var totalInferences: Int = 0
    private var sosDetectionCount: Int = 0
    private var falsePositiveCount: Int = 0  // User can increment via debug UI

    // MARK: - Initialization

    override init() {
        super.init()
        NSLog("[KeywordSpotter] 🔄 Initializing CoreML Sound Classifier...")
        print("[KeywordSpotter] 🔄 Initializing CoreML Sound Classifier...")
        loadModel()
    }

    // MARK: - Model Loading

    private func loadModel() {
        audioQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                // Load CoreML model from bundle
                NSLog("[KeywordSpotter] 🔍 Searching for model in bundle...")
                guard let modelURL = Bundle.main.url(forResource: "SOSKeywordClassifier", withExtension: "mlmodelc") ??
                                     Bundle.main.url(forResource: "SOSKeywordClassifier", withExtension: "mlmodel") else {
                    NSLog("[KeywordSpotter] ❌ Model file not found in bundle!")
                    throw NSError(domain: "KeywordSpotter", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "SOSKeywordClassifier.mlmodel not found in bundle"
                    ])
                }

                NSLog("[KeywordSpotter] ✅ Found model at: %@", modelURL.path)

                // Create sound classification request
                let request = try SNClassifySoundRequest(mlModel: MLModel(contentsOf: modelURL))
                self.soundClassifier = request

                NSLog("[KeywordSpotter] ✅ CoreML Sound Classifier loaded successfully!")
                print("[KeywordSpotter] ✅ CoreML Sound Classifier loaded")
                print("[KeywordSpotter]    Model: SOSKeywordClassifier")
                print("[KeywordSpotter]    Classes: sos, oh_ess, noise, unknown")

                DispatchQueue.main.async {
                    self.isModelLoaded = true
                }

            } catch {
                NSLog("[KeywordSpotter] ❌ Model loading failed: %@", error.localizedDescription)
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load CoreML model: \(error.localizedDescription)"
                    print("[KeywordSpotter] ❌ Model loading failed: \(error)")
                }
            }
        }
    }

    // MARK: - Audio Recording Control

    func startListening() {
        NSLog("[KeywordSpotter] 🎤 startListening() called")

        guard isModelLoaded else {
            NSLog("[KeywordSpotter] ⚠️ Cannot start - model not loaded")
            print("[KeywordSpotter] ⚠️  Cannot start - model not loaded")
            return
        }

        guard !isListening else {
            NSLog("[KeywordSpotter] Already listening")
            print("[KeywordSpotter] Already listening")
            return
        }

        NSLog("[KeywordSpotter] Requesting microphone permission...")

        // Request microphone permission
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                guard let self = self else { return }
                NSLog("[KeywordSpotter] Microphone permission: %@", granted ? "GRANTED" : "DENIED")
                if granted {
                    self.setupAudioEngine()
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Microphone permission denied"
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                guard let self = self else { return }
                NSLog("[KeywordSpotter] Microphone permission: %@", granted ? "GRANTED" : "DENIED")
                if granted {
                    self.setupAudioEngine()
                }
            }
        }
    }

    func stopListening() {
        guard isListening else { return }

        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        streamAnalyzer?.removeAllRequests()
        streamAnalyzer = nil

        DispatchQueue.main.async {
            self.isListening = false
            print("[KeywordSpotter] 🛑 Stopped listening")
        }
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true)

            audioEngine = AVAudioEngine()
            inputNode = audioEngine?.inputNode

            guard let inputNode = inputNode else {
                throw NSError(domain: "KeywordSpotter", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to get audio input node"
                ])
            }

            // Create stream analyzer
            let inputFormat = inputNode.outputFormat(forBus: 0)
            streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)

            // Add classification request
            guard let soundClassifier = soundClassifier,
                  let streamAnalyzer = streamAnalyzer else {
                throw NSError(domain: "KeywordSpotter", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to initialize sound classifier or analyzer"
                ])
            }

            try streamAnalyzer.add(soundClassifier, withObserver: self)

            // Install tap to feed audio to analyzer
            inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { [weak self] buffer, time in
                guard let self = self else { return }
                self.audioQueue.async {
                    // Check audio quality before analysis
                    let (hasVoice, energy, peak) = self.hasVoiceActivity(buffer)

                    // Log audio quality periodically (every 10 buffers)
                    if self.totalInferences % 10 == 0 {
                        NSLog("[KeywordSpotter] 🎤 Audio: RMS=%.6f, Peak=%.6f, Voice=%@",
                              energy, peak, hasVoice ? "YES" : "NO")
                    }

                    // Only analyze if we have actual audio (not silence)
                    if hasVoice {
                        self.streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
                    } else {
                        // Log silence detection less frequently
                        if self.totalInferences % 50 == 0 {
                            NSLog("[KeywordSpotter] 🔇 Skipping inference - silence/low audio detected")
                        }
                    }
                }
            }

            audioEngine?.prepare()
            try audioEngine?.start()

            DispatchQueue.main.async {
                self.isListening = true
                print("[KeywordSpotter] 🎤 Started listening for SOS keyword")
            }

        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
                print("[KeywordSpotter] ❌ Audio setup failed: \(error)")
            }
        }
    }

    // MARK: - External Audio (ESP32 BLE)

    func setExternalAudioEnabled(_ enabled: Bool) {
        useExternalAudio = enabled
        print("[KeywordSpotter] External audio: \(enabled ? "enabled" : "disabled")")

        if enabled {
            setupExternalAudioAnalyzer()
        } else {
            externalStreamAnalyzer?.removeAllRequests()
            externalStreamAnalyzer = nil
        }
    }

    private func setupExternalAudioAnalyzer() {
        do {
            // Create audio format for external audio (typically 16kHz mono from ESP32)
            guard let externalFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 16000,
                channels: 1,
                interleaved: false
            ) else {
                print("[KeywordSpotter] ❌ Failed to create external audio format")
                return
            }

            externalStreamAnalyzer = SNAudioStreamAnalyzer(format: externalFormat)

            guard let soundClassifier = soundClassifier,
                  let analyzer = externalStreamAnalyzer else { return }

            try analyzer.add(soundClassifier, withObserver: self)
            print("[KeywordSpotter] ✅ External audio analyzer ready")

        } catch {
            print("[KeywordSpotter] ❌ External audio setup failed: \(error)")
        }
    }

    func feedExternalAudio(_ samples: [Int16]) {
        guard useExternalAudio, let analyzer = externalStreamAnalyzer else { return }

        audioQueue.async { [weak self] in
            guard let self = self else { return }

            // Convert to PCM buffer
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 16000,
                channels: 1,
                interleaved: false
            ),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
                return
            }

            buffer.frameLength = buffer.frameCapacity

            // Copy samples to buffer
            if let channelData = buffer.int16ChannelData {
                let dest = channelData[0]
                samples.withUnsafeBufferPointer { source in
                    dest.update(from: source.baseAddress!, count: samples.count)
                }
            }

            // Analyze the buffer
            analyzer.analyze(buffer, atAudioFramePosition: 0)
        }
    }

    // MARK: - Audio Quality & Voice Activity Detection

    /// Check if audio buffer has voice activity (not silence or pure noise)
    private func hasVoiceActivity(_ buffer: AVAudioPCMBuffer) -> (hasVoice: Bool, energy: Float, peakAmplitude: Float) {
        guard let channelData = buffer.floatChannelData?[0] else {
            return (false, 0, 0)
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return (false, 0, 0)
        }

        // Calculate energy and peak amplitude
        var totalEnergy: Float = 0
        var peakAmplitude: Float = 0

        for i in 0..<frameLength {
            let sample = channelData[i]
            totalEnergy += sample * sample
            peakAmplitude = max(peakAmplitude, abs(sample))
        }

        let energy = totalEnergy / Float(frameLength)
        let rmsEnergy = sqrt(energy)

        // Voice activity thresholds (lowered to match your actual audio levels)
        let minEnergy: Float = 0.0003  // RMS energy threshold (was 0.001)
        let minPeak: Float = 0.003     // Peak amplitude threshold (was 0.01)

        let hasVoice = rmsEnergy > minEnergy && peakAmplitude > minPeak

        if !hasVoice {
            NSLog("[KeywordSpotter] ⚠️ Low audio quality - RMS: %.6f, Peak: %.6f", rmsEnergy, peakAmplitude)
        }

        return (hasVoice, rmsEnergy, peakAmplitude)
    }

    // MARK: - Performance Monitoring

    /// Calculate false positive rate (requires manual marking of false positives)
    private func falsePositiveRate() -> Float {
        guard sosDetectionCount > 0 else { return 0.0 }
        return Float(falsePositiveCount) / Float(sosDetectionCount)
    }

    /// Get detection statistics for debugging/monitoring
    func getPerformanceStats() -> (totalInferences: Int, detections: Int, falsePositives: Int, fpRate: Float) {
        return (totalInferences, sosDetectionCount, falsePositiveCount, falsePositiveRate())
    }

    /// Reset performance counters (for testing)
    func resetPerformanceStats() {
        totalInferences = 0
        sosDetectionCount = 0
        falsePositiveCount = 0
        print("[KeywordSpotter] 📊 Performance stats reset")
    }

    /// Mark last detection as false positive (for user feedback)
    func markLastDetectionAsFalsePositive() {
        falsePositiveCount += 1
        print("[KeywordSpotter] ⚠️ Marked false positive. Total FP: \(falsePositiveCount)/\(sosDetectionCount)")
    }

    /// Get current detection parameters (for UI display)
    func getDetectionParameters() -> (threshold: Float, deltaThreshold: Float, consecutiveRequired: Int, smoothingWindow: Int) {
        return (detectionThreshold, confidenceDeltaThreshold, requiredConsecutiveDetections, historySize)
    }
}

// MARK: - SNResultsObserving

extension KeywordSpotter: SNResultsObserving {

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classificationResult = result as? SNClassificationResult else { return }

        // Increment inference counter
        totalInferences += 1

        // Get classifications sorted by confidence
        let classifications = classificationResult.classifications
            .sorted { $0.confidence > $1.confidence }

        guard let topClassification = classifications.first else { return }

        // Look for SOS classification
        let sosClassification = classifications.first { $0.identifier.lowercased() == "sos" }
        let sosConfidence = Float(sosClassification?.confidence ?? 0.0)

        // Get second-best class for delta comparison
        let secondBestConf = classifications.count > 1 ? Float(classifications[1].confidence) : 0.0
        let secondBestClass = classifications.count > 1 ? classifications[1].identifier : "none"

        // Calculate confidence delta (how much SOS is winning by)
        let confidenceDelta = sosConfidence - secondBestConf

        // Update confidence history with smoothing
        if smoothingEnabled {
            recentSOSConfidences.append(sosConfidence)
            if recentSOSConfidences.count > historySize {
                recentSOSConfidences.removeFirst()
            }
        }

        let smoothedConfidence = smoothingEnabled ?
            recentSOSConfidences.reduce(0, +) / Float(recentSOSConfidences.count) : sosConfidence

        // Log classification results with delta
        let topClass = topClassification.identifier
        let topConf = topClassification.confidence

        // Enhanced diagnostics: Show ALL class confidences periodically
        if totalInferences % 20 == 0 {
            var allConfs = "All classes: "
            for classification in classifications {
                allConfs += "\(classification.identifier)=\(String(format: "%.3f", classification.confidence)) "
            }
            NSLog("[KeywordSpotter] 📊 %@", allConfs)
        }

        // Warning if SOS confidence is suspiciously low for extended period
        if sosConfidence < 0.01 {
            if totalInferences % 100 == 0 {
                NSLog("[KeywordSpotter] ⚠️ WARNING: SOS confidence has been near-zero for 100 inferences")
                NSLog("[KeywordSpotter] 💡 This suggests:")
                NSLog("[KeywordSpotter]    1. Microphone picking up only ambient noise")
                NSLog("[KeywordSpotter]    2. Audio format mismatch with model")
                NSLog("[KeywordSpotter]    3. Model needs retraining with better SOS samples")
            }
        }

        NSLog("[KeywordSpotter] 🔊 %@: %.3f | SOS: %.3f | 2nd: %@(%.3f) | Δ: %.3f",
              topClass, topConf, sosConfidence, secondBestClass, secondBestConf, confidenceDelta)
        print("[KeywordSpotter] 🔊 \(topClass): \(String(format: "%.3f", topConf)) | SOS: \(String(format: "%.3f", sosConfidence)) | Δ: \(String(format: "%.3f", confidenceDelta))")

        // SIMPLIFIED DETECTION LOGIC: SOS ≥ 0.6 → Alert (with debounce only)
        let now = Date()
        let canDetect = lastSOSDetectionTime == nil ||
                       now.timeIntervalSince(lastSOSDetectionTime!) >= minDetectionInterval

        // Use raw confidence (not smoothed) for immediate response
        let detectionConfidence = sosConfidence

        // SINGLE CHECK: Is SOS confidence above threshold?
        let shouldTriggerAlert = detectionConfidence >= detectionThreshold

        if shouldTriggerAlert {
            NSLog("[KeywordSpotter] ✅ SOS threshold met: %.3f >= %.3f", detectionConfidence, detectionThreshold)
        }

        // Trigger alert if threshold met and debounce allows
        if shouldTriggerAlert && canDetect {
            lastSOSDetectionTime = now
            consecutiveSOSDetections = 0  // Reset for next detection
            sosDetectionCount += 1
            let detectionTime = now

            // Format timestamp with milliseconds
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            let timeString = formatter.string(from: detectionTime)

            // Determine confidence level for logging
            let confidenceLevel: String
            let emoji: String
            if detectionConfidence >= 0.9 {
                confidenceLevel = "EXCELLENT"
                emoji = "🔥"
            } else if detectionConfidence >= 0.7 {
                confidenceLevel = "HIGH"
                emoji = "✅"
            } else if detectionConfidence >= 0.6 {
                confidenceLevel = "MODERATE"
                emoji = "⚠️"
            } else {
                confidenceLevel = "WEAK"
                emoji = "❗"
            }

            NSLog("[KeywordSpotter] %@ SOS ALERT TRIGGERED at %@ | Confidence: %.3f (%@) | Delta: %.3f | Count: %d/%d",
                  emoji, timeString, detectionConfidence, confidenceLevel, confidenceDelta, sosDetectionCount, totalInferences)

            // Trigger notification via AlertManager
            let latency = Date().timeIntervalSince(detectionTime) * 1000  // ms
            alertManager.triggerSOSVoiceAlert(
                confidence: Double(detectionConfidence),
                detectionTime: timeString,
                latencyMs: latency
            )
            NSLog("[KeywordSpotter] ✅ Alert notification sent to AlertManager (conf: %.3f)", detectionConfidence)

            // Update UI on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                let alertTime = Date()
                let latency = alertTime.timeIntervalSince(detectionTime) * 1000  // ms

                let detection = KeywordDetection(
                    timestamp: alertTime,
                    detectionTimestamp: detectionTime,
                    keyword: "SOS",
                    confidence: detectionConfidence
                )
                self.latestDetection = detection
                self.averageConfidence = detectionConfidence

                NSLog("[KeywordSpotter] Alert created at %@ (%.1fms latency) | FP rate: %.2f%%",
                      formatter.string(from: alertTime), latency,
                      self.falsePositiveRate() * 100)
                print("[KeywordSpotter] 🚨 SOS DETECTED! Confidence: \(String(format: "%.3f", detectionConfidence)) | Delta: \(String(format: "%.3f", confidenceDelta))")
            }
        } else {
            // Update average confidence even when not detecting SOS
            DispatchQueue.main.async { [weak self] in
                self?.averageConfidence = Float(topConf)
            }
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        NSLog("[KeywordSpotter] ❌ Classification error: %@", error.localizedDescription)
        print("[KeywordSpotter] ❌ Classification error: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = "Classification failed: \(error.localizedDescription)"
        }
    }

    func requestDidComplete(_ request: SNRequest) {
        NSLog("[KeywordSpotter] Request completed")
        print("[KeywordSpotter] Request completed")
    }
}
