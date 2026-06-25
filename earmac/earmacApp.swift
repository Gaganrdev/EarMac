import SwiftUI

@main
struct earmacApp: App {
    @State private var bluetooth = BluetoothManager()

    var body: some Scene {
        MenuBarExtra("earmac", systemImage: menuBarIcon) {
            ContentView()
                .environment(bluetooth)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRootView()
                .environment(bluetooth)
        }
    }

    private var menuBarIcon: String {
        switch bluetooth.connectionState {
        case .connected:            return "airpodspro"
        case .scanning:             return "antenna.radiowaves.left.and.right"
        case .connecting:           return "antenna.radiowaves.left.and.right"
        case .discoveringServices:  return "antenna.radiowaves.left.and.right"
        case .poweredOff:           return "airpodspro.slash"
        case .error:                return "exclamationmark.triangle"
        case .disconnected:         return "airpodspro"
        }
    }
}
