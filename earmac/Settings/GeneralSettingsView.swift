import SwiftUI

struct GeneralSettingsView: View {
    @Environment(BluetoothManager.self) private var bluetooth
    @AppStorage("autoReconnect") private var autoReconnect = false
    @AppStorage("lowBatteryNotifications") private var lowBatteryNotifications = false
    @AppStorage("lowBatteryThreshold") private var lowBatteryThreshold = 15

    var body: some View {
        Form {
            Section("Connection") {
                Toggle("Auto-reconnect on disconnect", isOn: $autoReconnect)
                    .onChange(of: autoReconnect) { _, newValue in
                        bluetooth.autoReconnect = newValue
                    }

                Text("Automatically attempts to reconnect up to 3 times when the connection drops.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Low battery alerts", isOn: $lowBatteryNotifications)
                    .onChange(of: lowBatteryNotifications) { _, newValue in
                        if newValue {
                            NotificationManager.shared.requestPermission()
                        }
                    }

                if lowBatteryNotifications {
                    HStack {
                        Text("Alert threshold")
                        Spacer()
                        Text("\(lowBatteryThreshold)%")
                            .font(.system(.body, design: .rounded).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: Binding(
                        get: { Double(lowBatteryThreshold) },
                        set: { lowBatteryThreshold = Int($0) }
                    ), in: 10...30, step: 5)
                    .labelsHidden()
                }
            }

            Section("About") {
                LabeledContent("App", value: "earmac")
                LabeledContent("Version", value: "2.0.0")

                if bluetooth.isConnected {
                    Divider()
                    LabeledContent("Device", value: bluetooth.deviceName ?? "Connected")
                    LabeledContent("Model", value: bluetooth.deviceModel.code)
                    if let fw = bluetooth.firmwareVersion {
                        LabeledContent("Firmware", value: fw)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
