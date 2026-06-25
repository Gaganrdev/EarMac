import SwiftUI

struct AudioSettingsView: View {
    @Environment(BluetoothManager.self) private var bluetooth
    @State private var customBass: Float = 0
    @State private var customMid: Float = 0
    @State private var customTreble: Float = 0

    var body: some View {
        Form {
            Section("Equalizer") {
                if bluetooth.isConnected {
                    eqPicker
                } else {
                    Text("Connect your earbuds to adjust audio settings")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }

            if bluetooth.eqPreset == .custom && bluetooth.isConnected {
                Section("Custom EQ") {
                    customEQSliders
                }
            }

            if bluetooth.deviceModel.supportsAdvancedEQ && bluetooth.isConnected {
                Section("Advanced EQ") {
                    Toggle("Enable Advanced EQ", isOn: Binding(
                        get: { bluetooth.isAdvancedEQEnabled ?? false },
                        set: { newValue in
                            bluetooth.setAdvancedEQ(enabled: newValue)
                        }
                    ))
                    .disabled(bluetooth.isSwitchingEQ)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: bluetooth.customEQ) { _, newValue in
            if let custom = newValue {
                customBass = Float(custom.bass)
                customMid = Float(custom.mid)
                customTreble = Float(custom.treble)
            }
        }
    }

    private var eqPicker: some View {
        Picker("Preset", selection: Binding(
            get: { bluetooth.eqPreset ?? .balanced },
            set: { newValue in
                bluetooth.setEQPreset(newValue)
            }
        )) {
            ForEach(EQPreset.allCases, id: \.self) { preset in
                Text(preset.displayName).tag(preset)
            }
        }
        .pickerStyle(.menu)
        .disabled(bluetooth.isSwitchingEQ)
    }

    private var customEQSliders: some View {
        VStack(spacing: 16) {
            EQSliderRow(label: "Bass", value: $customBass, symbol: "music.note.low")
            EQSliderRow(label: "Mid", value: $customMid, symbol: "music.note")
            EQSliderRow(label: "Treble", value: $customTreble, symbol: "music.note.high")

            Button("Apply Custom EQ") {
                let custom = EQPresetCustom(
                    bass: Int(customBass),
                    mid: Int(customMid),
                    treble: Int(customTreble)
                )
                bluetooth.setCustomEQ(custom)
            }
            .buttonStyle(.borderedProminent)
            .disabled(bluetooth.isSwitchingEQ)
        }
    }
}

struct EQSliderRow: View {
    let label: String
    @Binding var value: Float
    let symbol: String

    var body: some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(label)
                .frame(width: 50, alignment: .leading)

            Slider(value: $value, in: -6...6, step: 1)
                .labelsHidden()

            Text("\(Int(value))")
                .font(.system(.body, design: .rounded).monospacedDigit())
                .frame(width: 30, alignment: .trailing)
                .foregroundStyle(value > 0 ? .green : (value < 0 ? .orange : .secondary))
        }
    }
}
