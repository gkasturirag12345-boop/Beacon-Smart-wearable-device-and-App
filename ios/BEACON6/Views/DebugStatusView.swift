//
//  DebugStatusView.swift
//  BEACON6
//
//  Debug view to show initialization status
//

import SwiftUI

struct DebugStatusView: View {
    @ObservedObject var healthService = HealthMonitoringService.shared
    @ObservedObject var keywordSpotter = HealthMonitoringService.shared.keywordSpotter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔍 Debug Status")
                .font(.headline)
                .padding(.bottom, 8)

            StatusRow(label: "Model Loaded",
                     status: keywordSpotter.isModelLoaded,
                     detail: keywordSpotter.errorMessage)

            StatusRow(label: "Listening",
                     status: keywordSpotter.isListening)

            if let detection = keywordSpotter.latestDetection {
                Text("Last Detection:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("  Class: \(detection.keyword)")
                    .font(.system(.body, design: .monospaced))

                Text("  Confidence: \(String(format: "%.2f", detection.confidence))")
                    .font(.system(.body, design: .monospaced))

                Text("  Time: \(detection.detectionTimeString)")
                    .font(.system(.body, design: .monospaced))

                Text("  Latency: \(String(format: "%.0f", detection.latencyMs))ms")
                    .font(.system(.body, design: .monospaced))

                Text("  Detected: \(detection.isDetected ? "✅ YES" : "❌ NO")")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(detection.isDetected ? .green : .red)
            }

            // Model file check
            if let modelURL = Bundle.main.url(forResource: "SOSKeywordClassifier", withExtension: "mlmodelc") {
                Text("✅ Model file found:")
                    .foregroundColor(.green)
                Text("  \(modelURL.lastPathComponent)")
                    .font(.system(.caption, design: .monospaced))
            } else if let modelURL = Bundle.main.url(forResource: "SOSKeywordClassifier", withExtension: "mlmodel") {
                Text("⚠️ Source model found (not compiled):")
                    .foregroundColor(.orange)
                Text("  \(modelURL.lastPathComponent)")
                    .font(.system(.caption, design: .monospaced))
            } else {
                Text("❌ Model file NOT found in bundle")
                    .foregroundColor(.red)
            }

            Divider()

            VStack(spacing: 12) {
                Button("🎤 Test: Say 'SOS' now") {
                    NSLog("[DEBUG] User tapped test button - say SOS now!")
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button("🚨 Test In-App SOS Alert") {
                    NSLog("[DEBUG] Manually triggering in-app SOS alert")

                    // Format current time with milliseconds
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm:ss.SSS"
                    let timeString = formatter.string(from: Date())

                    // Manually trigger the SOS banner for testing
                    healthService.sosAlertMessage = "TEST: SOS keyword detected with 95.0% confidence"
                    healthService.sosAlertConfidence = 0.95
                    healthService.sosDetectionTime = timeString
                    healthService.sosLatencyMs = 10.0  // Simulated latency
                    healthService.showSOSBanner = true

                    // Haptic feedback
                    #if canImport(UIKit)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    #endif
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button("📱 Test iOS Notification") {
                    NSLog("[DEBUG] Manually triggering iOS notification")

                    // Format current time
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm:ss.SSS"
                    let timeString = formatter.string(from: Date())

                    // Trigger the full alert system with timing info
                    healthService.alertManager.triggerSOSVoiceAlert(
                        confidence: 0.95,
                        detectionTime: timeString,
                        latencyMs: 25.0
                    )
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(12)
    }
}

struct StatusRow: View {
    let label: String
    let status: Bool
    var detail: String? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(status ? "✅" : "❌")
            Text(status ? "YES" : "NO")
                .foregroundColor(status ? .green : .red)
                .font(.subheadline)
        }

        if let detail = detail, !detail.isEmpty {
            Text(detail)
                .font(.caption)
                .foregroundColor(.red)
        }
    }
}

#Preview {
    DebugStatusView()
}
