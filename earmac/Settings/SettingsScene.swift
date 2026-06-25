import SwiftUI

struct SettingsRootView: View {
    @Environment(BluetoothManager.self) private var bluetooth

    var body: some View {
        TabView {
            Tab("Audio", systemImage: "waveform") {
                AudioSettingsView()
            }
            Tab("Features", systemImage: "checkmark.circle") {
                FeaturesSettingsView()
            }
            Tab("General", systemImage: "gear") {
                GeneralSettingsView()
            }
        }
        .frame(minWidth: 420, minHeight: 360)
    }
}
