//
//  BLEConnectionView.swift
//  BEACON
//
//  Modern Bluetooth device connection interface
//

import SwiftUI
import CoreBluetooth

struct BLEConnectionView: View {
    @EnvironmentObject var healthService: HealthMonitoringService
    @ObservedObject var bleManager: BLEManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Layout.spacingXLarge) {
                    // Connection Status Card
                    connectionStatusCard

                    // Connected Device Info
                    if let device = bleManager.connectedDevice {
                        connectedDeviceCard(device: device)
                    }

                    // Control Buttons
                    controlButtons

                    // Discovered Devices List
                    if !bleManager.discoveredDevices.isEmpty && !bleManager.isConnected {
                        discoveredDevicesSection
                    }

                    // Empty State / Help
                    if !bleManager.isConnected && bleManager.discoveredDevices.isEmpty && !bleManager.isScanning {
                        emptyStateView
                    }

                    // Scanning Indicator
                    if bleManager.isScanning {
                        scanningIndicator
                    }
                }
                .padding(AppTheme.Layout.paddingLarge)
            }
            .background(AppTheme.Colors.groupedBackground)
            .navigationTitle("Bluetooth")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Connection Status Card

    private var connectionStatusCard: some View {
        ModernCard {
            HStack(spacing: AppTheme.Layout.spacingLarge) {
                // Icon with animation
                ZStack {
                    Circle()
                        .fill(bleManager.isConnected ? AppTheme.Colors.success.opacity(0.15) : AppTheme.Colors.textSecondary.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: bleManager.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 40))
                        .foregroundColor(bleManager.isConnected ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
                }
                .pulseEffect(isActive: bleManager.isConnected)

                // Status Text
                VStack(alignment: .leading, spacing: AppTheme.Layout.spacingSmall) {
                    Text(bleManager.isConnected ? "Connected" : "Disconnected")
                        .font(AppTheme.Typography.sectionTitle)
                        .foregroundColor(bleManager.isConnected ? AppTheme.Colors.success : AppTheme.Colors.textPrimary)

                    Text(bleManager.connectionStatus)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    if bleManager.isConnected {
                        StatusBadge(
                            text: "ACTIVE",
                            color: AppTheme.Colors.success,
                            style: .filled
                        )
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Connected Device Card

    private func connectedDeviceCard(device: CBPeripheral) -> some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                HStack {
                    Text("Connected Device")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Spacer()

                    PulseDot(color: AppTheme.Colors.success, isAnimating: true)
                }

                Divider()

                HStack(spacing: AppTheme.Layout.spacingMedium) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: AppTheme.Layout.iconLarge))
                        .foregroundColor(AppTheme.Colors.bluetooth)
                        .frame(width: 50, height: 50)
                        .background(AppTheme.Colors.bluetooth.opacity(0.15))
                        .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name ?? "ESP32-C3 Device")
                            .font(AppTheme.Typography.bodyBold)
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        Text("UUID: \(device.identifier.uuidString.prefix(18))...")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        Group {
            if bleManager.isConnected {
                ModernButton(
                    title: "Disconnect Device",
                    icon: "xmark.circle.fill",
                    style: .destructive
                ) {
                    healthService.disconnect()
                }
            } else {
                ModernButton(
                    title: bleManager.isScanning ? "Stop Scanning" : "Scan for Devices",
                    icon: bleManager.isScanning ? "stop.circle.fill" : "magnifyingglass",
                    style: bleManager.isScanning ? .secondary : .primary,
                    isLoading: bleManager.isScanning
                ) {
                    if bleManager.isScanning {
                        healthService.stopBLEScanning()
                    } else {
                        healthService.startBLEScanning()
                    }
                }
            }
        }
    }

    // MARK: - Discovered Devices Section

    private var discoveredDevicesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
            HStack {
                Text("Available Devices")
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()

                StatusBadge(
                    text: "\(bleManager.discoveredDevices.count)",
                    color: AppTheme.Colors.bluetooth,
                    style: .filled
                )
            }

            VStack(spacing: AppTheme.Layout.spacingSmall) {
                ForEach(bleManager.discoveredDevices, id: \.identifier) { peripheral in
                    deviceRow(peripheral: peripheral)
                }
            }
        }
    }

    private func deviceRow(peripheral: CBPeripheral) -> some View {
        Button(action: {
            HapticFeedback.medium()
            healthService.connect(to: peripheral)
        }) {
            HStack(spacing: AppTheme.Layout.spacingMedium) {
                // Device Icon
                Image(systemName: "cpu")
                    .font(.system(size: AppTheme.Layout.iconMedium))
                    .foregroundColor(AppTheme.Colors.bluetooth)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.Colors.bluetooth.opacity(0.15))
                    .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

                // Device Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(peripheral.name ?? "Unknown Device")
                        .font(AppTheme.Typography.bodyBold)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text(peripheral.identifier.uuidString)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Connect Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(AppTheme.Layout.paddingLarge)
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(AppTheme.Layout.cornerRadiusLarge)
            .shadow(
                color: AppTheme.Shadows.small.color,
                radius: AppTheme.Shadows.small.radius,
                x: AppTheme.Shadows.small.x,
                y: AppTheme.Shadows.small.y
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "antenna.radiowaves.left.and.right",
            title: "No Devices Found",
            message: "Turn on your ESP32-C3 device and tap 'Scan for Devices' to begin.",
            actionTitle: "Start Scanning",
            action: {
                healthService.startBLEScanning()
            }
        )
    }

    // MARK: - Scanning Indicator

    private var scanningIndicator: some View {
        ModernCard {
            HStack(spacing: AppTheme.Layout.spacingMedium) {
                ModernSpinner()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Scanning for devices...")
                        .font(AppTheme.Typography.bodyBold)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text("Make sure your device is powered on")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                Spacer()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BLEConnectionView(bleManager: BLEManager())
        .environmentObject(HealthMonitoringService.shared)
}
