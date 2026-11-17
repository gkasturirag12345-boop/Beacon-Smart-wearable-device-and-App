//
//  KeywordSpottingView.swift
//  BEACON
//
//  SOS Keyword Detection UI
//  Real-time visualization of keyword spotting results
//
//  Created: October 15, 2025
//

import SwiftUI

struct KeywordSpottingView: View {
    @StateObject private var keywordSpotter = KeywordSpotter()
    @EnvironmentObject var bleManager: BLEManager

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("SOS Voice Detection")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)

            // Model Status
            modelStatusCard

            // Detection Display
            detectionCard

            // Controls
            controlButtons

            // Detection History
            if let detection = keywordSpotter.latestDetection {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Latest Detection")
                        .font(.headline)
                        .padding(.horizontal)

                    DetectionHistoryRow(detection: detection)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Voice Detection")
        .onChange(of: keywordSpotter.latestDetection) { detection in
            handleDetection(detection)
        }
    }

    // MARK: - Subviews

    private var modelStatusCard: some View {
        HStack {
            Circle()
                .fill(keywordSpotter.isModelLoaded ? Color.green : Color.gray)
                .frame(width: 12, height: 12)

            Text(keywordSpotter.isModelLoaded ? "Model Ready" : "Loading Model...")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            if let error = keywordSpotter.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .help(error)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var detectionCard: some View {
        VStack(spacing: 16) {
            // Real-time indicator
            HStack {
                if keywordSpotter.isListening {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .scaleEffect(keywordSpotter.isListening ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 0.8).repeatForever(), value: keywordSpotter.isListening)

                    Text("Listening...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 10, height: 10)

                    Text("Idle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Average confidence meter
                if keywordSpotter.isListening {
                    Text("Avg: \(String(format: "%.1f%%", keywordSpotter.averageConfidence * 100))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Latest detection result
            if let detection = keywordSpotter.latestDetection {
                VStack(spacing: 12) {
                    // Keyword detected indicator
                    if detection.isDetected {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                            Text("SOS DETECTED")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }

                    // Detection details
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Keyword")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(detection.keyword.uppercased())
                                .font(.headline)
                                .foregroundColor(detection.keyword == "SOS" ? .red : .primary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Confidence")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", detection.confidence * 100))%")
                                .font(.headline)
                                .foregroundColor(detection.isDetected ? .green : .primary)
                        }
                    }

                    // Confidence progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                                .cornerRadius(4)

                            Rectangle()
                                .fill(detection.isDetected ? Color.red : Color.blue)
                                .frame(width: geometry.size.width * CGFloat(detection.confidence), height: 8)
                                .cornerRadius(4)

                            // Threshold indicator
                            Rectangle()
                                .fill(Color.orange)
                                .frame(width: 2, height: 12)
                                .offset(x: geometry.size.width * CGFloat(detection.threshold))
                        }
                    }
                    .frame(height: 12)

                    Text("Threshold: \(String(format: "%.1f", detection.threshold * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No detections yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var controlButtons: some View {
        HStack(spacing: 16) {
            // Start/Stop Button
            Button(action: {
                if keywordSpotter.isListening {
                    keywordSpotter.stopListening()
                } else {
                    keywordSpotter.startListening()
                }
            }) {
                HStack {
                    Image(systemName: keywordSpotter.isListening ? "stop.circle.fill" : "mic.circle.fill")
                    Text(keywordSpotter.isListening ? "Stop Listening" : "Start Listening")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(keywordSpotter.isListening ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!keywordSpotter.isModelLoaded)
        }
    }

    // MARK: - Detection Handling

    private func handleDetection(_ detection: KeywordDetection?) {
        guard let detection = detection, detection.isDetected else { return }

        print("[KeywordSpottingView] 🚨 SOS keyword detected - triggering alert")

        // Trigger alert in AlertManager
        AlertManager.shared.triggerSOSVoiceAlert(confidence: Double(detection.confidence))

        // Send BLE notification to ESP32-C3
        if bleManager.isConnected {
            bleManager.sendSOSKeywordDetected(confidence: detection.confidence)
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - Detection History Row

struct DetectionHistoryRow: View {
    let detection: KeywordDetection

    var body: some View {
        HStack {
            // Icon
            Image(systemName: detection.isDetected ? "exclamationmark.circle.fill" : "waveform")
                .foregroundColor(detection.isDetected ? .red : .blue)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(detection.keyword.uppercased())
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(detection.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Confidence badge
            Text("\(String(format: "%.0f", detection.confidence * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(detection.isDetected ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
                .foregroundColor(detection.isDetected ? .red : .secondary)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// MARK: - Preview

struct KeywordSpottingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            KeywordSpottingView()
                .environmentObject(BLEManager())
        }
    }
}
