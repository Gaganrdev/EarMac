import Foundation
@preconcurrency import CoreBluetooth
import UserNotifications

private func earLog(_ message: String) {
    let line = "[earmac] " + message + "\n"
    let path = "/tmp/earmac-debug.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        handle.closeFile()
    } else {
        try? line.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

enum ConnectionState: Sendable, Equatable {
    case disconnected
    case scanning
    case connecting
    case discoveringServices
    case connected
    case poweredOff
    case error(String)

    var isTransitioning: Bool {
        switch self {
        case .scanning, .connecting, .discoveringServices: true
        default: false
        }
    }
}

@Observable
@MainActor
final class BluetoothManager {

    var connectionState: ConnectionState = .disconnected
    var deviceName: String?
    var deviceModel: DeviceModel = .unknown
    var serialNumber: String?
    var firmwareVersion: String?
    var battery: BatteryInfo?
    var ancMode: ANCMode?
    var isSwitchingANC = false

    var eqPreset: EQPreset?
    var customEQ: EQPresetCustom?
    var isAdvancedEQEnabled: Bool?
    var spatialAudioMode: SpatialAudioMode?
    var inEarDetection: Bool?
    var isSwitchingEQ = false
    var isSwitchingSpatial = false
    var isSwitchingInEar = false

    var autoReconnect = UserDefaults.standard.bool(forKey: "autoReconnect")

    var isConnected: Bool {
        if case .connected = connectionState { return true }
        return false
    }

    private let fastPairUUID = CBUUID(string: "FE2C")

    private let standardServices: Set<String> = [
        "1800", "1801", "180A", "180F",
        "1844", "1846", "184D", "184E", "184F",
        "1850", "1853", "1855", "FE2C"
    ]

    private let preferredServiceUUIDs: [String: Int] = [
        "0000FD90-0000-1000-8000-00805F9B34FB": 300
    ]

    private let delegate: BluetoothDelegate
    @ObservationIgnored nonisolated(unsafe) var centralManager: CBCentralManager?
    @ObservationIgnored nonisolated(unsafe) var connectedPeripheral: CBPeripheral?
    @ObservationIgnored nonisolated(unsafe) var writeCharacteristic: CBCharacteristic?
    @ObservationIgnored nonisolated(unsafe) var notifyCharacteristic: CBCharacteristic?

    private var candidateServices: [CBService] = []
    private var servicesToCheck = 0
    private var servicesChecked = 0
    private var bestServiceScore = -1

    private var operationID: UInt8 = 1
    private var batteryPollingTask: Task<Void, Never>?
    private var connectionTimeoutTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private var lastLowBatteryNotification: [String: Date] = [:]

    private var hasSerialNumber = false
    private var hasFirmware = false
    private var isInitialQueryComplete = false

    init() {
        let delegate = BluetoothDelegate()
        self.delegate = delegate
        delegate.manager = self
        self.centralManager = CBCentralManager(delegate: delegate, queue: .main)
    }

    func startConnecting() {
        guard let cm = centralManager else {
            earLog("startConnecting: centralManager is nil")
            return
        }
        guard cm.state == .poweredOn else {
            earLog("startConnecting: Bluetooth not powered on (state=\(cm.state.rawValue))")
            connectionState = .poweredOff
            return
        }
        earLog("startConnecting: Bluetooth powered on, attempting connection")
        reconnectAttempts = 0
        connectToKnownDeviceOrScan()
    }

    func disconnect() {
        earLog("disconnect: user-initiated disconnect")
        reconnectAttempts = 3
        batteryPollingTask?.cancel()
        batteryPollingTask = nil
        if let peripheral = connectedPeripheral, let cm = centralManager {
            cm.cancelPeripheralConnection(peripheral)
        }
    }

    func setANC(_ mode: ANCMode) {
        guard isConnected else { return }
        isSwitchingANC = true
        sendRequest(EarRequest.setANC(mode, opID: nextOperationID()))
    }

    func setEQPreset(_ preset: EQPreset) {
        guard isConnected else { return }
        isSwitchingEQ = true
        if deviceModel.supportsListeningMode {
            sendRequest(EarRequest.setListeningMode(preset, opID: nextOperationID()))
        } else {
            sendRequest(EarRequest.setEQPreset(preset, opID: nextOperationID()))
        }
    }

    func setCustomEQ(_ custom: EQPresetCustom) {
        guard isConnected else { return }
        isSwitchingEQ = true
        sendRequest(EarRequest.setCustomEQ(custom, specs: deviceModel.eqPresetCustomSpecs, opID: nextOperationID()))
    }

    func setAdvancedEQ(enabled: Bool) {
        guard isConnected else { return }
        isSwitchingEQ = true
        sendRequest(EarRequest.setAdvancedEQ(enabled: enabled, opID: nextOperationID()))
    }

    func setSpatialAudio(_ mode: SpatialAudioMode) {
        guard isConnected else { return }
        isSwitchingSpatial = true
        sendRequest(EarRequest.setSpatialAudio(mode, opID: nextOperationID()))
    }

    func setInEarDetection(_ enabled: Bool) {
        guard isConnected else { return }
        isSwitchingInEar = true
        sendRequest(EarRequest.setInEarDetection(enabled, opID: nextOperationID()))
    }

    private let knownDeviceNames: Set<String> = [
        "Nothing ear (1)", "Ear (Stick)", "Ear (2)", "Nothing Ear",
        "Nothing Ear (a)", "Nothing Ear (open)", "Nothing Ear (3)",
        "Nothing Headphone (1)", "Nothing Headphone (a)",
        "Buds Pro", "Neckband Pro", "CMF Buds", "CMF Buds Pro 2",
        "CMF Buds 2", "CMF Buds 2 Plus", "CMF Buds 2a",
        "CMF Headphone Pro"
    ]

    private func isKnownDevice(_ name: String?) -> Bool {
        guard let name else { return false }
        return knownDeviceNames.contains { name.contains($0) }
    }

    private func connectToKnownDeviceOrScan() {
        guard let cm = centralManager else { return }

        let known = cm.retrieveConnectedPeripherals(withServices: [fastPairUUID])
        earLog("connectToKnownDeviceOrScan: found \(known.count) already-connected peripherals with FE2C")

        for peripheral in known {
            earLog("connectToKnownDeviceOrScan: checking '\(peripheral.name ?? "unknown")' isKnown=\(isKnownDevice(peripheral.name))")
        }

        if let peripheral = known.first(where: { isKnownDevice($0.name) }) {
            earLog("connectToKnownDeviceOrScan: connecting to '\(peripheral.name ?? "unknown")'")
            connectionState = .connecting
            connect(to: peripheral)
            return
        }

        earLog("connectToKnownDeviceOrScan: no known peripherals, starting scan for FE2C")
        connectionState = .scanning
        cm.scanForPeripherals(withServices: [fastPairUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if case .scanning = connectionState {
                earLog("connectToKnownDeviceOrScan: FE2C scan timed out after 10s, trying open scan")
                cm.stopScan()
                cm.scanForPeripherals(withServices: nil, options: nil)
                connectionState = .scanning

                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if case .scanning = connectionState {
                    earLog("connectToKnownDeviceOrScan: open scan also timed out, no devices found")
                    cm.stopScan()
                    connectionState = .error("No earbuds found nearby")
                }
            }
        }
    }

    private func connect(to peripheral: CBPeripheral) {
        centralManager?.stopScan()
        connectionState = .connecting
        connectedPeripheral = peripheral
        centralManager?.connect(peripheral, options: nil)
    }

    private func nextOperationID() -> UInt8 {
        operationID = operationID >= 250 ? 1 : operationID + 1
        return operationID
    }

    private func sendRequest(_ frame: EarFrame) {
        guard let peripheral = connectedPeripheral,
              let writeChar = writeCharacteristic else {
            earLog("sendRequest: no peripheral or write characteristic")
            return
        }
        let data = Data(frame.encoded())
        let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        earLog("sendRequest: cmd=0x\(String(frame.command, radix: 16)) \(data.count) bytes: \(hex)")
        peripheral.writeValue(data, for: writeChar, type: .withoutResponse)
    }

    private func queryInitialDeviceInfo() {
        earLog("queryInitialDeviceInfo: starting")
        hasSerialNumber = false
        hasFirmware = false
        isInitialQueryComplete = false

        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled else { return }
            if !isInitialQueryComplete {
                earLog("queryInitialDeviceInfo: TIMEOUT")
                connectionState = .error("Connection timed out")
                if let p = connectedPeripheral, let cm = centralManager {
                    cm.cancelPeripheralConnection(p)
                }
            }
        }

        sendRequest(EarRequest.readSerialNumber(opID: nextOperationID()))
    }

    private func completeInitialQuery() {
        guard !isInitialQueryComplete, hasSerialNumber, hasFirmware else { return }
        isInitialQueryComplete = true
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        reconnectAttempts = 0

        connectionState = .connected

        sendRequest(EarRequest.readBattery(opID: nextOperationID()))

        let tasks: [(TimeInterval, () -> Void)] = [
            (0.2, { self.sendRequest(self.deviceModel.supportsANC ? EarRequest.readANC(opID: self.nextOperationID()) : nil) }),
            (0.4, { self.queryAudioFeatures() }),
            (0.6, { self.queryFeatureSettings() }),
        ]

        for (delay, task) in tasks {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                task()
            }
        }

        startBatteryPolling()
    }

    private func queryAudioFeatures() {
        if deviceModel.supportsListeningMode {
            sendRequest(EarRequest.readListeningMode(opID: nextOperationID()))
        } else if deviceModel.supportsEQ {
            sendRequest(EarRequest.readEQ(opID: nextOperationID()))
        }

        if deviceModel.supportsCustomEQ {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)
                sendRequest(EarRequest.readCustomEQ(opID: nextOperationID()))
            }
        }

        if deviceModel.supportsAdvancedEQ {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                sendRequest(EarRequest.readAdvancedEQ(opID: nextOperationID()))
            }
        }

        if deviceModel.supportsSpatialAudio {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                sendRequest(EarRequest.readSpatialAudio(opID: nextOperationID()))
            }
        }
    }

    private func queryFeatureSettings() {
        if deviceModel.supportsInEarDetection {
            sendRequest(EarRequest.readInEarDetection(opID: nextOperationID()))
        }
    }

    private func sendRequest(_ frame: EarFrame?) {
        guard let frame else { return }
        sendRequest(frame)
    }

    private func startBatteryPolling() {
        batteryPollingTask?.cancel()
        batteryPollingTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled, isConnected else { break }
                sendRequest(EarRequest.readBattery(opID: nextOperationID()))
            }
        }
    }

    private func resetState() {
        connectedPeripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        candidateServices.removeAll()
        servicesToCheck = 0
        servicesChecked = 0
        bestServiceScore = -1
        hasSerialNumber = false
        hasFirmware = false
        isInitialQueryComplete = false
        batteryPollingTask?.cancel()
        batteryPollingTask = nil
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
        battery = nil
        ancMode = nil
        isSwitchingANC = false
        eqPreset = nil
        customEQ = nil
        isAdvancedEQEnabled = nil
        spatialAudioMode = nil
        inEarDetection = nil
        isSwitchingEQ = false
        isSwitchingSpatial = false
        isSwitchingInEar = false
        lastLowBatteryNotification.removeAll()
    }

    private func processResponse(_ data: Data) {
        guard let response = EarResponse(Array(data)) else {
            earLog("processResponse: failed to parse \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            return
        }

        earLog("processResponse: cmd=0x\(String(response.command, radix: 16)) payload=\(response.payload.map { String(format: "%02X", $0) }.joined(separator: " "))")

        switch response.command {
        case EarCommand.Response.serialNumber:
            let name = connectedPeripheral?.name ?? "Unknown"
            if let serial = response.parseSerialNumber() {
                earLog("processResponse: got serial number")
                serialNumber = serial
                deviceModel = DeviceModel.detect(deviceName: name, serialNumber: serial)
                deviceName = deviceModel == .unknown ? name : deviceModel.displayName
                hasSerialNumber = true

                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    sendRequest(EarRequest.readFirmware(opID: nextOperationID()))
                }
            } else {
                earLog("processResponse: failed to parse serial number")
            }

        case EarCommand.Response.firmware:
            let fw = response.parseFirmwareVersion()
            if !fw.isEmpty {
                firmwareVersion = fw
                hasFirmware = true
                completeInitialQuery()
            }

        case EarCommand.Response.batteryA, EarCommand.Response.batteryB:
            battery = response.parseBattery()
            checkLowBattery()

        case EarCommand.Response.ancA, EarCommand.Response.ancB:
            ancMode = response.parseANCMode()
            isSwitchingANC = false

        case EarCommand.Response.eqA, EarCommand.Response.eqB:
            eqPreset = response.parseEQPreset()
            isSwitchingEQ = false

        case EarCommand.Response.customEQ:
            customEQ = response.parseCustomEQ()
            isSwitchingEQ = false

        case EarCommand.Response.advancedEQ, EarCommand.Response.advancedEQWrite:
            if response.payload.isEmpty {
                isAdvancedEQEnabled = false
            } else {
                isAdvancedEQEnabled = response.payload[0] != 0
            }
            isSwitchingEQ = false

        case EarCommand.Response.spatialAudio:
            spatialAudioMode = response.parseSpatialAudioMode()
            isSwitchingSpatial = false

        case EarCommand.Response.inEarDetection:
            inEarDetection = response.parseInEarDetection()
            isSwitchingInEar = false

        default:
            break
        }
    }

    private func checkLowBattery() {
        guard let battery,
              UserDefaults.standard.bool(forKey: "lowBatteryNotifications")
        else { return }

        checkLowBatteryFor(battery.leftBud, budName: "Left bud")
        checkLowBatteryFor(battery.rightBud, budName: "Right bud")
        checkLowBatteryFor(battery.caseBattery, budName: "Case")
    }

    private func checkLowBatteryFor(_ level: BatteryLevel, budName: String) {
        guard level.isConnected, !level.isCharging, level.level <= (thresholdValue) else { return }

        if let lastNotified = lastLowBatteryNotification[budName],
           Date().timeIntervalSince(lastNotified) < 300
        {
            return
        }

        lastLowBatteryNotification[budName] = Date()
        NotificationManager.shared.sendLowBattery(level: level.level, budName: budName)
    }

    private var thresholdValue: Int {
        let t = UserDefaults.standard.integer(forKey: "lowBatteryThreshold")
        return t > 0 ? t : 15
    }

    private func attemptAutoReconnect() {
        guard autoReconnect, reconnectAttempts < 3 else {
            connectionState = .disconnected
            return
        }

        reconnectAttempts += 1
        connectionState = .disconnected

        reconnectTask?.cancel()
        reconnectTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled, autoReconnect else { return }
            startConnecting()
        }
    }

    private func serviceScore(_ service: CBService, hasWrite: Bool, hasNotify: Bool,
                              writeChar: CBCharacteristic?, notifyChar: CBCharacteristic?) -> Int {
        guard hasWrite && hasNotify else { return -1 }

        var score = 100
        let uuid = service.uuid.uuidString.uppercased()

        if uuid.hasPrefix("FD") && uuid.count == 4 { score += 50 }
        if uuid.count > 8 { score += 30 }
        if let bonus = preferredServiceUUIDs[uuid] { score += bonus }
        if let w = writeChar, w.properties.contains(.write) { score += 10 }
        if let n = notifyChar, n.properties.contains(.notify) { score += 10 }

        return score
    }
}

extension BluetoothManager {

    func handleCentralStateChange(_ state: CBManagerState) {
        earLog("handleCentralStateChange: state=\(state.rawValue)")
        switch state {
        case .poweredOn:
            if connectionState == .disconnected || connectionState == .poweredOff {
                connectToKnownDeviceOrScan()
            }
        case .poweredOff:
            connectionState = .poweredOff
        case .unauthorized:
            connectionState = .error("Bluetooth not authorized")
        default:
            break
        }
    }

    func handleDiscoveredPeripheral(_ peripheral: CBPeripheral) {
        let name = peripheral.name ?? "unknown"
        earLog("handleDiscoveredPeripheral: '\(name)' isKnown=\(isKnownDevice(peripheral.name))")
        guard isKnownDevice(peripheral.name) else { return }
        connect(to: peripheral)
    }

    func handleConnected(_ peripheral: CBPeripheral) {
        earLog("handleConnected: '\(peripheral.name ?? "unknown")'")
        connectionState = .discoveringServices
        deviceName = peripheral.name
        peripheral.delegate = delegate
        peripheral.discoverServices(nil)
    }

    func handleFailedToConnect(_ message: String) {
        earLog("handleFailedToConnect: \(message)")
        resetState()
        if autoReconnect && reconnectAttempts < 3 {
            attemptAutoReconnect()
        } else {
            connectionState = .error(message)
        }
    }

    func handleDisconnected() {
        earLog("handleDisconnected")
        let wasConnected = isConnected
        resetState()
        if wasConnected && autoReconnect {
            attemptAutoReconnect()
        } else {
            connectionState = .disconnected
        }
    }

    func handleDiscoveredServices(_ peripheral: CBPeripheral, error: Error?) {
        guard let services = peripheral.services, error == nil else {
            earLog("handleDiscoveredServices: no services")
            connectionState = .error("No services found")
            return
        }

        earLog("handleDiscoveredServices: \(services.count) services")
        for s in services { earLog("  service: \(s.uuid.uuidString)") }

        let candidates = services.filter { service in
            !standardServices.contains(service.uuid.uuidString.uppercased())
        }

        earLog("handleDiscoveredServices: \(candidates.count) proprietary candidates")

        candidateServices = candidates
        servicesToCheck = candidates.count
        servicesChecked = 0
        bestServiceScore = -1

        if candidates.isEmpty {
            connectionState = .error("No proprietary service found")
            return
        }

        for service in candidates {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func handleDiscoveredCharacteristics(_ service: CBService, error: Error?) {
        guard let characteristics = service.characteristics, error == nil else {
            servicesChecked += 1
            checkServiceDiscoveryComplete()
            return
        }

        earLog("handleDiscoveredCharacteristics: \(characteristics.count) chars for \(service.uuid.uuidString)")

        var foundWrite: CBCharacteristic?
        var foundNotify: CBCharacteristic?

        for char in characteristics {
            earLog("  char: \(char.uuid.uuidString) props=\(char.properties.rawValue)")

            if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                foundWrite = char
            }
            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                foundNotify = char
            }
        }

        let score = serviceScore(service, hasWrite: foundWrite != nil, hasNotify: foundNotify != nil,
                                 writeChar: foundWrite, notifyChar: foundNotify)

        if score > bestServiceScore, let write = foundWrite, let notify = foundNotify {
            bestServiceScore = score
            writeCharacteristic = write
            notifyCharacteristic = notify
            earLog("  selected write=\(write.uuid.uuidString) notify=\(notify.uuid.uuidString)")
        }

        servicesChecked += 1
        checkServiceDiscoveryComplete()
    }

    func handleCharacteristicData(_ data: Data) {
        processResponse(data)
    }

    private func checkServiceDiscoveryComplete() {
        guard servicesChecked >= servicesToCheck else { return }

        guard let notify = notifyCharacteristic,
              let peripheral = connectedPeripheral,
              writeCharacteristic != nil else {
            earLog("checkServiceDiscoveryComplete: no write/notify found")
            connectionState = .error("No write/notify characteristics found")
            return
        }

        earLog("checkServiceDiscoveryComplete: subscribing to notify \(notify.uuid.uuidString)")
        peripheral.setNotifyValue(true, for: notify)
    }

    func handleNotifySubscription(_ characteristic: CBCharacteristic, error: Error?) {
        if let error {
            earLog("handleNotifySubscription: FAILED - \(error.localizedDescription)")
            connectionState = .error("Failed to subscribe: \(error.localizedDescription)")
            return
        }

        earLog("handleNotifySubscription: subscribed successfully to \(characteristic.uuid.uuidString)")

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            queryInitialDeviceInfo()
        }
    }

    func handleWriteResult(_ characteristic: CBCharacteristic, error: Error?) {
        if let error {
            earLog("handleWriteResult: WRITE FAILED - \(error.localizedDescription)")
        }
    }
}
