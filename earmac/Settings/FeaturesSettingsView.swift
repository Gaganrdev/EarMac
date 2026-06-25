import SwiftUI

struct FeaturesSettingsView: View {
    @Environment(BluetoothManager.self) private var bluetooth

    var body: some View {
        Form {
            Section("In-Ear Detection") {
                if bluetooth.isConnected && bluetooth.deviceModel.supportsInEarDetection {
                    Toggle("Enable In-Ear Detection", isOn: Binding(
                        get: { bluetooth.inEarDetection ?? false },
                        set: { newValue in
                            bluetooth.setInEarDetection(newValue)
                        }
                    ))
                    .disabled(bluetooth.isSwitchingInEar)

                    Text("Pauses playback when earbuds are removed from your ears.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !bluetooth.isConnected {
                    Text("Connect your earbuds to configure features")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    Text("In-ear detection is not supported by this device.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
    }
}
