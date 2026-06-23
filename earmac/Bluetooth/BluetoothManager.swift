import Foundation
@preconcurrency import CoreBluetooth

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

    private var hasSerialNumber = false
    private var hasFirmware = false
    private var isInitialQueryComplete = false

    init() {
        let delegate = BluetoothDelegate()
        self.delegate = delegate
        self.centralManager = CBCentralManager(delegate: delegate, queue: nil)
        delegate.manager = self
    }

    func startConnecting() {
        guard let cm = centralManager, cm.state == .poweredOn else {
            connectionState = .poweredOff
            return
        }
        connectToKnownDeviceOrScan()
    }

    func disconnect() {
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

    private func connectToKnownDeviceOrScan() {
        guard let cm = centralManager else { return }
        let known = cm.retrieveConnectedPeripherals(withServices: [fastPairUUID])
        if let peripheral = known.first {
            connectionState = .connecting
            connect(to: peripheral)
            return
        }
        connectionState = .scanning
        cm.scanForPeripherals(withServices: [fastPairUUID])
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
            return
        }
        let data = Data(frame.encoded())
        peripheral.writeValue(data, for: writeChar, type: .withResponse)
    }

    private func queryInitialDeviceInfo() {
        hasSerialNumber = false
        hasFirmware = false
        isInitialQueryComplete = false

        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            if !isInitialQueryComplete {
                connectionState = .error("Connection timed out")
                if let p = connectedPeripheral, let cm = centralManager {
                    cm.cancelPeripheralConnection(p)
                }
            }
        }

        sendRequest(EarRequest.readSerialNumber(opID: nextOperationID()))

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            sendRequest(EarRequest.readFirmware(opID: nextOperationID()))
        }
    }

    private func completeInitialQuery() {
        guard !isInitialQueryComplete, hasSerialNumber, hasFirmware else { return }
        isInitialQueryComplete = true
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil

        connectionState = .connected

        sendRequest(EarRequest.readBattery(opID: nextOperationID()))

        if deviceModel.supportsANC {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                sendRequest(EarRequest.readANC(opID: nextOperationID()))
            }
        }

        startBatteryPolling()
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
    }

    private func processResponse(_ data: Data) {
        guard let response = EarResponse(Array(data)) else {
            return
        }

        switch response.command {
        case EarCommand.Response.serialNumber:
            let name = connectedPeripheral?.name ?? "Unknown"
            if let serial = response.parseSerialNumber() {
                serialNumber = serial
                deviceModel = DeviceModel.detect(deviceName: name, serialNumber: serial)
                deviceName = deviceModel == .unknown ? name : deviceModel.displayName
                hasSerialNumber = true
                completeInitialQuery()
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

        case EarCommand.Response.ancA, EarCommand.Response.ancB:
            ancMode = response.parseANCMode()
            isSwitchingANC = false

        default:
            break
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
        connect(to: peripheral)
    }

    func handleConnected(_ peripheral: CBPeripheral) {
        connectionState = .discoveringServices
        deviceName = peripheral.name
        peripheral.delegate = delegate
        peripheral.discoverServices(nil)
    }

    func handleFailedToConnect(_ message: String) {
        resetState()
        connectionState = .error(message)
    }

    func handleDisconnected() {
        resetState()
        connectionState = .disconnected
    }

    func handleDiscoveredServices(_ peripheral: CBPeripheral, error: Error?) {
        guard let services = peripheral.services, error == nil else {
            connectionState = .error("No services found")
            return
        }

        let candidates = services.filter { service in
            !standardServices.contains(service.uuid.uuidString.uppercased())
        }

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

        var foundWrite: CBCharacteristic?
        var foundNotify: CBCharacteristic?

        for char in characteristics {
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
            connectionState = .error("No write/notify characteristics found")
            return
        }

        peripheral.setNotifyValue(true, for: notify)
        queryInitialDeviceInfo()
    }
}
