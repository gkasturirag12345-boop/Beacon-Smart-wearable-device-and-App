//
//  TestModeView.swift
//  BEACON
//
//  Test mode view for iOS-native testing
//

import SwiftUI

struct TestModeView: View {
    @EnvironmentObject var healthService: HealthMonitoringService
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertType: AlertType = .info

    enum AlertType {
        case success, warning, error, info

        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .info: return .blue
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Alert Banner
                    if showAlert {
                        HStack {
                            Image(systemName: alertType.icon)
                                .foregroundColor(alertType.color)
                            Text(alertMessage)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: { showAlert = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(alertType.color.opacity(0.2))
                        .cornerRadius(10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Status: \(healthService.connectionStatus)")
                            .foregroundColor(healthService.isConnected ? .green : .red)
                            .font(.headline)

                        if healthService.isTestMode {
                            Text("Test Mode Active")
                                .foregroundColor(.blue)
                                .font(.subheadline)
                        }

                        if let hr = healthService.currentHeartRate {
                            Text("Current Heart Rate: \(Int(hr)) BPM")
                                .font(.body)
                        }

                        Text("Wear Status: \(healthService.currentWearStatus.rawValue)")
                            .font(.body)
                            .foregroundColor(
                                healthService.currentWearStatus == .worn ? .green : .orange
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)

                    // Test Mode Toggle
                    VStack(spacing: 15) {
                        Text("Test Mode")
                            .font(.headline)

                        Toggle("Enable Test Mode", isOn: Binding(
                            get: { healthService.isTestMode },
                            set: { enabled in
                                if enabled {
                                    healthService.enableTestMode()
                                    showAlertMessage("✅ Test mode enabled - generating simulated data", type: .success)
                                } else {
                                    healthService.disableTestMode()
                                    showAlertMessage("Test mode disabled", type: .info)
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .padding(.horizontal)

                        Text("Test mode generates realistic simulated data without requiring hardware")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color(white: 0.95))
                    .cornerRadius(10)

                    if healthService.isTestMode {
                        VStack(spacing: 15) {
                            Text("Trigger Test Scenarios")
                                .font(.headline)

                            Button("Test High Heart Rate Alert") {
                                healthService.triggerTestHeartRateHigh()
                                showAlertMessage("⚠️ Triggering high heart rate alert (135 BPM)", type: .warning)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)

                            Button("Test Low Heart Rate Alert") {
                                healthService.triggerTestHeartRateLow()
                                showAlertMessage("⚠️ Triggering low heart rate alert (35 BPM)", type: .warning)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)

                            Button("Test Fall Detection Alert") {
                                healthService.triggerTestFall()
                                showAlertMessage("🚨 Triggering fall detection alert!", type: .error)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)

                            Text("Wear status toggles automatically every 10 seconds")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color(white: 0.95))
                        .cornerRadius(10)

                        // Recent Alerts
                        if !healthService.activeAlerts.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Recent Alerts")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(healthService.activeAlerts.prefix(5)) { alert in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(alert.message)
                                                .font(.subheadline)
                                            Text(alert.timestamp, style: .relative)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if !alert.resolved {
                                            Button("Resolve") {
                                                healthService.resolveAlert(alert.id)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding()
                                    .background(Color(white: 0.9))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Test Mode")
            .background(Color(white: 0.95))
        }
    }

    private func showAlertMessage(_ message: String, type: AlertType) {
        withAnimation {
            alertMessage = message
            alertType = type
            showAlert = true
        }

        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
                showAlert = false
            }
        }
    }
}

#Preview {
    TestModeView()
        .environmentObject(HealthMonitoringService.shared)
}
