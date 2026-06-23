import SwiftUI

struct ContentView: View {
    @Environment(BluetoothManager.self) private var bluetooth

    var body: some View {
        Group {
            if bluetooth.isConnected {
                ConnectedView()
            } else {
                DisconnectedView()
            }
        }
        .frame(width: 320)
        .animation(.snappy(duration: 0.25), value: bluetooth.isConnected)
    }
}

// MARK: - Disconnected / Transitioning

struct DisconnectedView: View {
    @Environment(BluetoothManager.self) private var bluetooth

    var body: some View {
        VStack(spacing: 20) {
            iconView
            statusText
            actionButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(.quaternary)
                .frame(width: 56, height: 56)

            Image(systemName: bluetooth.connectionState.isTransitioning ? "antenna.radiowaves.left.and.right" : "airpodspro")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
                .symbolEffect(.variableColor.iterative, isActive: bluetooth.connectionState.isTransitioning)
        }
    }

    private var statusText: some View {
        VStack(spacing: 4) {
            Text(headerText)
                .font(.headline)

            if let subtitle = subtitleText {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var actionButton: some View {
        Group {
            switch bluetooth.connectionState {
            case .disconnected:
                Button {
                    bluetooth.startConnecting()
                } label: {
                    Label("Connect", systemImage: "airpodspro")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            case .error:
                Button {
                    bluetooth.startConnecting()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

            case .poweredOff:
                EmptyView()

            default:
                ProgressView()
                    .controlSize(.regular)
            }
        }
    }

    private var headerText: String {
        switch bluetooth.connectionState {
        case .disconnected:          return "Not Connected"
        case .scanning:              return "Scanning…"
        case .connecting:            return "Connecting…"
        case .discoveringServices:   return "Setting up…"
        case .poweredOff:            return "Bluetooth Off"
        case .error(let msg):        return msg
        case .connected:             return ""
        }
    }

    private var subtitleText: String? {
        switch bluetooth.connectionState {
        case .scanning:    return "Looking for your earbuds nearby"
        case .connecting:  return "Establishing connection"
        case .discoveringServices: return "Discovering services"
        case .poweredOff:  return "Turn on Bluetooth to continue"
        case .disconnected: return "Make sure your earbuds are paired in System Settings"
        default: return nil
        }
    }
}

// MARK: - Connected

struct ConnectedView: View {
    @Environment(BluetoothManager.self) private var bluetooth

    var body: some View {
        VStack(spacing: 12) {
            DeviceHeaderCard()

            if bluetooth.battery != nil {
                BatteryCard()
            }

            if bluetooth.deviceModel.supportsANC {
                ANCControlCard()
            }

            InfoFooter()

            Divider()
                .padding(.horizontal, 16)

            DisconnectButton()
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Device Header

struct DeviceHeaderCard: View {
    @Environment(BluetoothManager.self) private var bluetooth

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "airpodspro")
                    .font(.system(size: 20))
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bluetooth.deviceName ?? "Earbuds")
                    .font(.headline)
                    .lineLimit(1)

                if let serial = bluetooth.serialNumber {
                    Text(serial)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Battery

struct BatteryCard: View {
    @Environment(BluetoothManager.self) private var bluetooth

    var body: some View {
        HStack(spacing: 0) {
            if let battery = bluetooth.battery {
                BatteryColumn(label: "Left", icon: "l.circle.fill", level: battery.leftBud)
                Divider().frame(height: 44)
                BatteryColumn(label: "Right", icon: "r.circle.fill", level: battery.rightBud)
                Divider().frame(height: 44)
                BatteryColumn(label: "Case", icon: "c.circle.fill", level: battery.caseBattery)
            }
        }
        .padding(.vertical, 12)
        .background(.quinary.opacity(0.5), in: .rect(cornerRadius: 12))
        .padding(.horizontal, 16)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct BatteryColumn: View {
    let label: String
    let icon: String
    let level: BatteryLevel

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(level.isConnected ? batteryColor : .secondary)
                .symbolEffect(.pulse, isActive: level.isCharging)

            if level.isConnected {
                Text("\(level.level)%")
                    .font(.system(size: 13, design: .rounded).weight(.medium))
                    .foregroundStyle(level.isCharging ? .green : .primary)
            } else {
                Text("--")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var batteryColor: Color {
        guard level.isConnected else { return .secondary }
        if level.isCharging { return .green }
        if level.level <= 15 { return .red }
        if level.level <= 30 { return .orange }
        return .primary
    }
}

// MARK: - ANC Control

struct ANCControlCard: View {
    @Environment(BluetoothManager.self) private var bluetooth

    private var currentGroup: ANCGroup {
        bluetooth.ancMode?.group ?? .off
    }

    private var ancLevelIndex: Int {
        guard let mode = bluetooth.ancMode else { return 1 }
        return ANCMode.ancLevels.firstIndex(of: mode) ?? 1
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: currentGroup.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Noise Control")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if bluetooth.isSwitchingANC {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            HStack(spacing: 8) {
                ForEach(ANCGroup.allCases, id: \.self) { group in
                    ANCGroupButton(
                        group: group,
                        isSelected: currentGroup == group,
                        isDisabled: bluetooth.isSwitchingANC
                    ) {
                        selectGroup(group)
                    }
                }
            }

            if currentGroup == .anc {
                VStack(spacing: 6) {
                    HStack {
                        Text("Intensity")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ANCMode.ancLevels[ancLevelIndex].displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.tint)
                    }

                    Picker("ANC Intensity", selection: Binding(
                        get: { ancLevelIndex },
                        set: { newIndex in
                            let mode = ANCMode.ancLevels[newIndex]
                            bluetooth.setANC(mode)
                        }
                    )) {
                        ForEach(Array(ANCMode.ancLevels.enumerated()), id: \.offset) { index, mode in
                            Text(mode.displayName).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(bluetooth.isSwitchingANC)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .padding(12)
        .background(.quinary.opacity(0.5), in: .rect(cornerRadius: 12))
        .padding(.horizontal, 16)
        .animation(.snappy(duration: 0.25), value: currentGroup)
        .animation(.snappy(duration: 0.2), value: bluetooth.isSwitchingANC)
    }

    private func selectGroup(_ group: ANCGroup) {
        switch group {
        case .off:
            bluetooth.setANC(.off)
        case .transparent:
            bluetooth.setANC(.transparent)
        case .anc:
            if currentGroup != .anc {
                bluetooth.setANC(.mid)
            }
        }
    }
}

struct ANCGroupButton: View {
    let group: ANCGroup
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: group.symbolName)
                    .font(.system(size: 18))
                Text(group.displayName)
                    .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(isSelected ? .white : .primary)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quinary))
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .animation(.snappy(duration: 0.2), value: isSelected)
    }
}

// MARK: - Info Footer

struct InfoFooter: View {
    @Environment(BluetoothManager.self) private var bluetooth

    var body: some View {
        HStack {
            Label("Firmware", systemImage: "cpu")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(bluetooth.firmwareVersion ?? "—")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Disconnect Button

struct DisconnectButton: View {
    @Environment(BluetoothManager.self) private var bluetooth

    var body: some View {
        Button {
            bluetooth.disconnect()
        } label: {
            Label("Disconnect", systemImage: "power")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(.red)
        .padding(.horizontal, 16)
    }
}
