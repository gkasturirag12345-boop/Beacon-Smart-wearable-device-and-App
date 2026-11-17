//
//  WiFiSetupView.swift
//  BEACON
//
//  Modern WiFi Setup and Configuration View
//

import SwiftUI

struct WiFiSetupViewModern: View {
    @StateObject private var provisioning = WiFiProvisioningService.shared
    @StateObject private var networkCoordinator = NetworkCoordinator.shared
    @EnvironmentObject var healthService: HealthMonitoringService

    @State private var ssid = ""
    @State private var password = ""
    @State private var showingPassword = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showProvisioningInstructions = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppTheme.Layout.spacingXLarge) {
                    // Connection Status Card
                    connectionStatusCard

                    // Network Scanner Card
                    networkScannerCard

                    // Discovered Networks
                    if !provisioning.availableNetworks.isEmpty {
                        discoveredNetworksSection
                    }

                    // WiFi Credentials Card
                    credentialsCard

                    // Saved Credentials (if any)
                    savedCredentialsSection

                    // Actions Card
                    actionsCard

                    // Debug Info (if connected)
                    if healthService.isConnected {
                        debugInfoCard
                    }

                    // Info Section
                    infoSection
                }
                .padding(AppTheme.Layout.paddingLarge)
            }
            .background(AppTheme.Colors.groupedBackground)
            .navigationTitle("WiFi Setup")
            .navigationBarTitleDisplayMode(.inline)
            .alert("WiFi Setup", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadSavedCredentials()
            }
        }
    }

    // MARK: - Connection Status Card

    private var connectionStatusCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                HStack {
                    Text("Connection Status")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Spacer()

                    ConnectionStatusBadge(
                        mode: networkCoordinator.currentMode,
                        isConnected: healthService.isConnected
                    )
                }

                Divider()

                // Current Mode
                HStack(spacing: AppTheme.Layout.spacingMedium) {
                    Image(systemName: networkCoordinator.currentMode.iconName)
                        .font(.system(size: AppTheme.Layout.iconLarge))
                        .foregroundColor(getColorForMode(networkCoordinator.currentMode))
                        .frame(width: 50, height: 50)
                        .background(getColorForMode(networkCoordinator.currentMode).opacity(0.15))
                        .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(networkCoordinator.currentMode.displayName)
                            .font(AppTheme.Typography.bodyBold)
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        Text(provisioning.getProvisioningStatusString())
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    Spacer()
                }

                // Device IP (if available)
                if let ip = provisioning.deviceIPAddress {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(AppTheme.Colors.wifi)
                        Text("Device IP:")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Spacer()
                        Text(ip)
                            .font(AppTheme.Typography.captionBold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .textSelection(.enabled)
                    }
                    .padding(AppTheme.Layout.paddingSmall)
                    .background(AppTheme.Colors.wifi.opacity(0.1))
                    .cornerRadius(AppTheme.Layout.cornerRadiusSmall)
                }
            }
        }
    }

    // MARK: - Network Scanner Card

    private var networkScannerCard: some View {
        ModernCard {
            VStack(spacing: AppTheme.Layout.spacingMedium) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scan for Networks")
                            .font(AppTheme.Typography.cardTitle)
                            .foregroundColor(AppTheme.Colors.textPrimary)

                        Text("Discover nearby WiFi networks via device")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }

                    Spacer()
                }

                ModernButton(
                    title: provisioning.isScanning ? "Scanning..." : "Scan for Networks",
                    icon: "wifi.circle.fill",
                    style: .primary,
                    isLoading: provisioning.isScanning,
                    isDisabled: !healthService.isConnected || !provisioning.bleCharacteristicsReady
                ) {
                    scanNetworks()
                }

                // BLE Status Indicators
                if !healthService.isConnected || !provisioning.bleCharacteristicsReady {
                    VStack(alignment: .leading, spacing: 8) {
                        if !healthService.isConnected {
                            StatusIndicator(
                                icon: "antenna.radiowaves.left.and.right.slash",
                                text: "BLE not connected",
                                color: .red,
                                isActive: false
                            )
                        }

                        if !provisioning.bleCharacteristicsReady && healthService.isConnected {
                            StatusIndicator(
                                icon: "hourglass",
                                text: "Initializing BLE...",
                                color: .orange,
                                isActive: false
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Discovered Networks Section

    private var discoveredNetworksSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
            HStack {
                Text("Available Networks")
                    .font(AppTheme.Typography.sectionTitle)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()

                StatusBadge(
                    text: "\(provisioning.availableNetworks.count)",
                    color: AppTheme.Colors.wifi,
                    style: .filled
                )
            }

            VStack(spacing: AppTheme.Layout.spacingSmall) {
                ForEach(provisioning.availableNetworks) { network in
                    networkRow(network: network)
                }
            }
        }
    }

    private func networkRow(network: WiFiNetwork) -> some View {
        Button(action: {
            HapticFeedback.selection()
            selectNetwork(network)
        }) {
            HStack(spacing: AppTheme.Layout.spacingMedium) {
                // WiFi Icon
                Image(systemName: network.secure ? "lock.wifi" : "wifi")
                    .font(.system(size: AppTheme.Layout.iconMedium))
                    .foregroundColor(AppTheme.Colors.wifi)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.Colors.wifi.opacity(0.15))
                    .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

                // Network Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(network.ssid)
                        .font(AppTheme.Typography.bodyBold)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    HStack(spacing: 8) {
                        SignalStrengthBadge(rssi: network.rssi)

                        if network.secure {
                            StatusBadge(text: "Secured", color: .green, style: .outlined)
                        }
                    }
                }

                Spacer()

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

    // MARK: - Credentials Card

    private var credentialsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                Text("WiFi Credentials")
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Divider()

                // SSID Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Network Name (SSID)")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    TextField("Enter WiFi name", text: $ssid)
                        .keyboardType(.default)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(AppTheme.Layout.paddingMedium)
                        .background(AppTheme.Colors.groupedBackground)
                        .cornerRadius(AppTheme.Layout.cornerRadiusMedium)
                }

                // Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)

                    HStack {
                        if showingPassword {
                            TextField("Enter password", text: $password)
                                .keyboardType(.default)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("Enter password", text: $password)
                                .textContentType(.password)
                        }

                        Button(action: {
                            HapticFeedback.selection()
                            showingPassword.toggle()
                        }) {
                            Image(systemName: showingPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(AppTheme.Layout.paddingMedium)
                    .background(AppTheme.Colors.groupedBackground)
                    .cornerRadius(AppTheme.Layout.cornerRadiusMedium)
                }

                // Provisioning Status
                provisioningStatusView

                // Connection Requirements Status
                if !healthService.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Connect to ESP32-BEACON via Bluetooth tab first")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(AppTheme.Layout.paddingSmall)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(AppTheme.Layout.cornerRadiusSmall)
                } else if !provisioning.bleCharacteristicsReady {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Initializing WiFi service... (wait 2 seconds)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(AppTheme.Layout.paddingSmall)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(AppTheme.Layout.cornerRadiusSmall)
                } else if ssid.isEmpty || password.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Enter network name and password to continue")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(AppTheme.Layout.paddingSmall)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(AppTheme.Layout.cornerRadiusSmall)
                }

                // Connect Button
                ModernButton(
                    title: "Connect to WiFi",
                    icon: "wifi",
                    style: .primary,
                    isDisabled: ssid.isEmpty || password.isEmpty || !healthService.isConnected || !provisioning.bleCharacteristicsReady
                ) {
                    connectToWiFi()
                }

                // Device Provisioning Button (Alternative Method)
                VStack(alignment: .leading, spacing: AppTheme.Layout.spacingSmall) {
                    Divider()
                        .padding(.vertical, AppTheme.Layout.paddingSmall)

                    Text("Alternative Setup Method")
                        .font(AppTheme.Typography.sectionTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text("Use the device's built-in captive portal for WiFi setup")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.bottom, AppTheme.Layout.paddingSmall)

                    ModernButton(
                        title: "Enter Device Setup Mode",
                        icon: "antenna.radiowaves.left.and.right",
                        style: .secondary,
                        isDisabled: !healthService.isConnected
                    ) {
                        enterDeviceSetupMode()
                    }

                    if showProvisioningInstructions {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Device entered setup mode!")
                                    .font(AppTheme.Typography.bodyBold)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                            }

                            Text("1. Connect to WiFi network 'Beacon5_Setup'")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)

                            Text("2. Portal will auto-open at http://192.168.4.1")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)

                            Text("3. Select your network and enter password")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)

                            Text("4. Tap 'Save & Connect' on the portal page")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .padding(AppTheme.Layout.paddingMedium)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(AppTheme.Layout.cornerRadiusMedium)
                    }
                }
            }
        }
    }

    // MARK: - Provisioning Status View

    @ViewBuilder
    private var provisioningStatusView: some View {
        switch provisioning.provisioningStatus {
        case .sendingCredentials:
            HStack(spacing: AppTheme.Layout.spacingMedium) {
                ProgressView()
                Text("Sending credentials...")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(AppTheme.Layout.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.info.opacity(0.1))
            .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

        case .waitingForConnection:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: AppTheme.Layout.spacingMedium) {
                    ProgressView()
                    Text("Device connecting...")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }

                Text("This may take up to 15 seconds")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(AppTheme.Layout.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.warning.opacity(0.1))
            .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

        case .connected:
            HStack(spacing: AppTheme.Layout.spacingMedium) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.Colors.success)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Connected!")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundColor(AppTheme.Colors.success)

                    if let ip = provisioning.deviceIPAddress {
                        Text("IP: \(ip)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(AppTheme.Layout.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.success.opacity(0.1))
            .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

        case .failed(let reason):
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: AppTheme.Layout.spacingMedium) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.Colors.danger)

                    Text("Connection Failed")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundColor(AppTheme.Colors.danger)
                }

                Text(reason)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                ModernButton(
                    title: "Retry Connection",
                    icon: "arrow.clockwise",
                    style: .secondary
                ) {
                    connectToWiFi()
                }
            }
            .padding(AppTheme.Layout.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.danger.opacity(0.1))
            .cornerRadius(AppTheme.Layout.cornerRadiusMedium)

        case .idle:
            EmptyView()
        }
    }

    // MARK: - Saved Credentials Section

    @ViewBuilder
    private var savedCredentialsSection: some View {
        let credentials = provisioning.getSavedCredentials()
        if let savedSSID = credentials.ssid {
            ModernCard {
                VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                    Text("Saved Configuration")
                        .font(AppTheme.Typography.cardTitle)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Divider()

                    HStack {
                        Image(systemName: "wifi")
                            .foregroundColor(AppTheme.Colors.wifi)
                        Text("Saved Network:")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Spacer()
                        Text(savedSSID)
                            .font(AppTheme.Typography.bodyBold)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }

                    HStack(spacing: AppTheme.Layout.spacingMedium) {
                        ModernButton(
                            title: "Load Credentials",
                            icon: "arrow.down.circle",
                            style: .secondary
                        ) {
                            let creds = provisioning.getSavedCredentials()
                            if let ssid = creds.ssid, let password = creds.password {
                                self.ssid = ssid
                                self.password = password
                                HapticFeedback.success()
                            }
                        }

                        ModernButton(
                            title: "Clear",
                            icon: "trash",
                            style: .destructive
                        ) {
                            clearCredentials()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions Card

    private var actionsCard: some View {
        ModernCard {
            VStack(spacing: AppTheme.Layout.spacingMedium) {
                ModernButton(
                    title: "Refresh Connection",
                    icon: "arrow.clockwise",
                    style: .secondary
                ) {
                    refreshConnection()
                }

                if networkCoordinator.currentMode == .wifi {
                    ModernButton(
                        title: "Force BLE Mode",
                        icon: "antenna.radiowaves.left.and.right",
                        style: .secondary
                    ) {
                        forceBLEMode()
                    }
                }
            }
        }
    }

    // MARK: - Debug Info Card

    private var debugInfoCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                Text("Connection Status")
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Divider()

                HStack {
                    Text("BLE Connected:")
                    Spacer()
                    StatusBadge(
                        text: healthService.isConnected ? "Yes" : "No",
                        color: healthService.isConnected ? .green : .red,
                        style: .filled
                    )
                }

                HStack {
                    Text("BLE Ready:")
                    Spacer()
                    StatusBadge(
                        text: provisioning.bleCharacteristicsReady ? "Yes" : "No",
                        color: provisioning.bleCharacteristicsReady ? .green : .red,
                        style: .filled
                    )
                }

                if provisioning.isScanning {
                    HStack {
                        Text("Scanning:")
                        Spacer()
                        StatusBadge(text: "In Progress", color: .orange, style: .filled)
                    }
                }

                if !provisioning.availableNetworks.isEmpty {
                    HStack {
                        Text("Networks Found:")
                        Spacer()
                        StatusBadge(
                            text: "\(provisioning.availableNetworks.count)",
                            color: .blue,
                            style: .filled
                        )
                    }
                }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: AppTheme.Layout.spacingMedium) {
                Text("Information")
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    WiFiInfoRow(icon: "wifi", text: "WiFi provides faster data transfer and longer range")
                    WiFiInfoRow(icon: "antenna.radiowaves.left.and.right", text: "BLE is always available as fallback")
                    WiFiInfoRow(icon: "arrow.triangle.2.circlepath", text: "Automatic switching between WiFi and BLE")
                    WiFiInfoRow(icon: "lock.fill", text: "All communication stays on local network")
                }
            }
        }
    }

    // MARK: - Actions

    // MARK: - Device Setup Mode (Captive Portal)

    private func enterDeviceSetupMode() {
        print("========================================")
        print("[WiFiSetup] 🔧 Enter Device Setup Mode button pressed")
        print("[WiFiSetup] Sending CHANGE_WIFI command via BLE...")
        print("========================================")

        guard healthService.isConnected else {
            print("[WiFiSetup] ❌ ERROR: BLE not connected")
            alertMessage = "Please connect to device via Bluetooth first"
            showAlert = true
            return
        }

        // Send CHANGE_WIFI command via BLE Control characteristic
        healthService.bleManager.sendControlCommand("CHANGE_WIFI")

        // Show instructions
        withAnimation(AnimationConfig.smooth) {
            showProvisioningInstructions = true
        }

        HapticFeedback.success()

        print("[WiFiSetup] ✅ CHANGE_WIFI command sent")
        print("[WiFiSetup] Device should now be in AP mode (Beacon5_Setup)")
    }

    // MARK: - WiFi Connection

    private func connectToWiFi() {
        print("========================================")
        print("[WiFiSetup] 🔵 Connect button pressed")
        print("[WiFiSetup] SSID: '\(ssid)'")
        print("[WiFiSetup] Password length: \(password.count) characters")
        print("[WiFiSetup] BLE connected: \(healthService.isConnected)")
        print("[WiFiSetup] BLE chars ready: \(provisioning.bleCharacteristicsReady)")
        print("========================================")

        guard healthService.isConnected else {
            print("[WiFiSetup] ❌ ERROR: BLE not connected")
            alertMessage = "Please connect to device via BLE first"
            showAlert = true
            return
        }

        guard !ssid.isEmpty && !password.isEmpty else {
            print("[WiFiSetup] ❌ ERROR: SSID or password empty")
            alertMessage = "Please enter both SSID and password"
            showAlert = true
            return
        }

        guard provisioning.bleCharacteristicsReady else {
            print("[WiFiSetup] ❌ ERROR: BLE characteristics not ready yet")
            alertMessage = "WiFi service not ready. Please wait 2 seconds after BLE connection."
            showAlert = true
            return
        }

        HapticFeedback.medium()
        print("[WiFiSetup] ✅ All checks passed - sending credentials to device...")
        provisioning.provisionWiFi(ssid: ssid, password: password)

        alertMessage = "WiFi credentials sent. Please wait for connection..."
        showAlert = true
    }

    private func clearCredentials() {
        HapticFeedback.warning()
        provisioning.clearSavedCredentials()
        ssid = ""
        password = ""

        alertMessage = "Credentials cleared"
        showAlert = true
    }

    private func refreshConnection() {
        HapticFeedback.medium()
        networkCoordinator.refreshConnection()

        alertMessage = "Refreshing connection..."
        showAlert = true
    }

    private func forceBLEMode() {
        HapticFeedback.medium()
        networkCoordinator.forceBLEMode()

        alertMessage = "Switched to BLE mode"
        showAlert = true
    }

    private func loadSavedCredentials() {
        let credentials = provisioning.getSavedCredentials()
        ssid = credentials.ssid ?? ""
        password = credentials.password ?? ""
    }

    private func scanNetworks() {
        print("[WiFiSetup] ========================================")
        print("[WiFiSetup] Scan button pressed")
        print("[WiFiSetup] BLE Connected: \(healthService.isConnected)")
        print("[WiFiSetup] BLE Ready: \(provisioning.bleCharacteristicsReady)")
        print("[WiFiSetup] Is Scanning: \(provisioning.isScanning)")
        print("[WiFiSetup] ========================================")

        guard healthService.isConnected else {
            alertMessage = "Please connect to device via BLE first.\n\nGo to Bluetooth tab and connect to ESP32-C3-HealthMonitor."
            showAlert = true
            print("[WiFiSetup] ❌ Scan failed: Not connected to BLE")
            return
        }

        guard provisioning.bleCharacteristicsReady else {
            alertMessage = "BLE not ready. Please wait a moment and try again.\n\nWait for 'Initializing BLE...' message to disappear."
            showAlert = true
            print("[WiFiSetup] ❌ Scan failed: BLE characteristics not ready")
            return
        }

        HapticFeedback.medium()
        print("[WiFiSetup] ✅ Starting WiFi scan...")
        provisioning.scanForNetworks()
    }

    private func selectNetwork(_ network: WiFiNetwork) {
        print("[WiFiSetup] Selected network: \(network.ssid)")
        ssid = network.ssid
        password = ""  // Clear password for security

        alertMessage = "Network '\(network.ssid)' selected.\nPlease enter the password below."
        showAlert = true
    }

    private func getColorForMode(_ mode: ConnectionMode) -> Color {
        switch mode {
        case .wifi:
            return .green
        case .ble:
            return .blue
        case .offline:
            return .red
        }
    }
}

// MARK: - Info Row Helper

private struct WiFiInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 24)
            Text(text)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    WiFiSetupViewModern()
        .environmentObject(HealthMonitoringService.shared)
}
