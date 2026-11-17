//
//  WiFiSetupView.swift
//  BEACON
//
//  WiFi Setup and Configuration View
//

import SwiftUI

struct WiFiSetupView: View {
    @StateObject private var provisioning = WiFiProvisioningService.shared
    @StateObject private var networkCoordinator = NetworkCoordinator.shared
    @EnvironmentObject var healthService: HealthMonitoringService

    @State private var ssid = ""
    @State private var password = ""
    @State private var showingPassword = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            Form {
                // Connection Status Section
                Section(header: Text("Connection Status")) {
                    HStack {
                        Image(systemName: networkCoordinator.currentMode.iconName)
                            .foregroundColor(getColorForMode(networkCoordinator.currentMode))
                        Text(networkCoordinator.currentMode.displayName)
                            .fontWeight(.semibold)
                        Spacer()
                        Circle()
                            .fill(getColorForMode(networkCoordinator.currentMode))
                            .frame(width: 12, height: 12)
                    }

                    Text(provisioning.getProvisioningStatusString())
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let ip = provisioning.deviceIPAddress {
                        HStack {
                            Text("Device IP:")
                            Spacer()
                            Text(ip)
                                .fontWeight(.medium)
                                .textSelection(.enabled)
                        }
                    }
                }

                // Available Networks Section
                Section(header: Text("Available Networks")) {
                    Button(action: scanNetworks) {
                        HStack {
                            Image(systemName: "wifi.circle.fill")
                                .foregroundColor(healthService.isConnected && provisioning.bleCharacteristicsReady ? .blue : .gray)
                            Text("Scan for Networks")
                            Spacer()
                            if provisioning.isScanning {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .disabled(!healthService.isConnected || !provisioning.bleCharacteristicsReady || provisioning.isScanning)
                    .opacity((healthService.isConnected && provisioning.bleCharacteristicsReady) ? 1.0 : 0.5)

                    // List of discovered networks
                    ForEach(provisioning.availableNetworks) { network in
                        Button(action: { selectNetwork(network) }) {
                            HStack {
                                Image(systemName: network.secure ? "lock.wifi" : "wifi")
                                    .foregroundColor(.blue)
                                Text(network.ssid)
                                Spacer()
                                Text("\(network.rssi) dBm")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                    }

                    if provisioning.isScanning {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Scanning for networks...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // WiFi Credentials Section
                Section(header: Text("WiFi Configuration")) {
                    // SSID Field - separate row for better touch handling
                    TextField("Network Name (SSID)", text: $ssid)
                        .keyboardType(.default)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    // Helper text - separate row
                    Text("Enter the same WiFi network your iPhone is connected to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)

                    // Password field with show/hide
                    HStack {
                        if showingPassword {
                            TextField("Password", text: $password)
                                .keyboardType(.default)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                        }

                        Button(action: { showingPassword.toggle() }) {
                            Image(systemName: showingPassword ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.borderless)  // Prevent button from blocking field
                    }

                    // Connection Status Progress
                    if case .sendingCredentials = provisioning.provisioningStatus {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Sending credentials...")
                                .foregroundColor(.secondary)
                        }
                    } else if case .waitingForConnection = provisioning.provisioningStatus {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Device connecting...")
                                    .foregroundColor(.secondary)
                                Text("This may take up to 15 seconds")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    } else if case .connected = provisioning.provisioningStatus {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("Connected!")
                                if let ip = provisioning.deviceIPAddress {
                                    Text("IP: \(ip)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    } else if case .failed(let reason) = provisioning.provisioningStatus {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Connection Failed")
                                    .foregroundColor(.red)
                            }
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: connectToWiFi) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry Connection")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Button(action: connectToWiFi) {
                        HStack {
                            Image(systemName: "wifi")
                            Text("Connect to WiFi")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(ssid.isEmpty || password.isEmpty || !healthService.isConnected || !provisioning.bleCharacteristicsReady)

                    // Show BLE readiness status
                    if healthService.isConnected && !provisioning.bleCharacteristicsReady {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Initializing BLE connection...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))

                // Saved Credentials Section
                let credentials = provisioning.getSavedCredentials()
                if let savedSSID = credentials.ssid {
                    Section(header: Text("Saved Configuration")) {
                        HStack {
                            Text("Saved Network:")
                            Spacer()
                            Text(savedSSID)
                                .foregroundColor(.secondary)
                        }

                        Button(action: {
                            let creds = provisioning.getSavedCredentials()
                            if let ssid = creds.ssid, let password = creds.password {
                                self.ssid = ssid
                                self.password = password
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                Text("Load Saved Credentials")
                            }
                        }

                        Button(role: .destructive, action: clearCredentials) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear Saved Credentials")
                            }
                        }
                    }
                }

                // Actions Section
                Section(header: Text("Actions")) {
                    Button(action: refreshConnection) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Connection")
                        }
                    }

                    if networkCoordinator.currentMode == .wifi {
                        Button(action: forceBLEMode) {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Force BLE Mode")
                            }
                        }
                    }
                }

                // Debug Section
                Section(header: Text("Connection Status")) {
                    HStack {
                        Text("BLE Connected:")
                        Spacer()
                        Text(healthService.isConnected ? "✅ Yes" : "❌ No")
                            .foregroundColor(healthService.isConnected ? .green : .red)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("BLE Ready:")
                        Spacer()
                        Text(provisioning.bleCharacteristicsReady ? "✅ Yes" : "❌ No")
                            .foregroundColor(provisioning.bleCharacteristicsReady ? .green : .red)
                            .fontWeight(.semibold)
                    }

                    if provisioning.isScanning {
                        HStack {
                            Text("Scanning:")
                            Spacer()
                            Text("⏳ In Progress")
                                .foregroundColor(.orange)
                                .fontWeight(.semibold)
                        }
                    }

                    if !provisioning.availableNetworks.isEmpty {
                        HStack {
                            Text("Networks Found:")
                            Spacer()
                            Text("\(provisioning.availableNetworks.count)")
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                }

                // Info Section
                Section(header: Text("Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        WiFiInfoRow(icon: "wifi", text: "WiFi provides faster data transfer and longer range")
                        WiFiInfoRow(icon: "antenna.radiowaves.left.and.right", text: "BLE is always available as fallback")
                        WiFiInfoRow(icon: "arrow.triangle.2.circlepath", text: "Automatic switching between WiFi and BLE")
                        WiFiInfoRow(icon: "lock.fill", text: "All communication stays on local network")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("WiFi Setup")
            .alert("WiFi Setup", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            loadSavedCredentials()
        }
    }

    // MARK: - Actions
    private func connectToWiFi() {
        guard healthService.isConnected else {
            alertMessage = "Please connect to device via BLE first"
            showAlert = true
            return
        }

        guard !ssid.isEmpty && !password.isEmpty else {
            alertMessage = "Please enter both SSID and password"
            showAlert = true
            return
        }

        print("[WiFiSetup] Sending credentials to device...")
        provisioning.provisionWiFi(ssid: ssid, password: password)

        alertMessage = "WiFi credentials sent. Please wait for connection..."
        showAlert = true
    }

    private func clearCredentials() {
        provisioning.clearSavedCredentials()
        ssid = ""
        password = ""

        alertMessage = "Credentials cleared"
        showAlert = true
    }

    private func refreshConnection() {
        networkCoordinator.refreshConnection()

        alertMessage = "Refreshing connection..."
        showAlert = true
    }

    private func forceBLEMode() {
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
            alertMessage = "Please connect to device via BLE first.\n\nGo to BLE Connection tab and connect to ESP32-C3-HealthMonitor."
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

    // MARK: - Helpers
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

// Info Row Helper
private struct WiFiInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    WiFiSetupView()
        .environmentObject(HealthMonitoringService.shared)
}
