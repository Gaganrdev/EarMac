import Foundation

enum EarRequest: Sendable {

    static func readBattery(opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Read.battery, payload: [], operationID: opID)
    }

    static func readSerialNumber(opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Read.serialNumber, payload: [], operationID: opID)
    }

    static func readFirmware(opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Read.firmware, payload: [], operationID: opID)
    }

    static func readANC(opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Read.anc, payload: [], operationID: opID)
    }

    static func setANC(_ mode: ANCMode, opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Write.anc, payload: [0x01, mode.wireValue, 0x00], operationID: opID)
    }
}
