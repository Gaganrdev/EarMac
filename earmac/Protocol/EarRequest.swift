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

    static func readEQ(opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Read.eq, payload: [], operationID: opID)
    }

    static func readListeningMode(opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Read.listeningMode, payload: [], operationID: opID)
    }

    static func setEQPreset(_ preset: EQPreset, opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Write.eq, payload: [preset.wireValue, 0x00], operationID: opID)
    }

    static func setListeningMode(_ preset: EQPreset, opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Write.listeningMode, payload: [preset.wireValue, 0x00], operationID: opID)
    }

    static func readCustomEQ(opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Read.customEQ, payload: [], operationID: opID)
    }

    static func setCustomEQ(_ custom: EQPresetCustom, specs: EQPresetCustomSpecs, opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Write.customEQ, payload: custom.encodedPayload(specs: specs), operationID: opID)
    }

    static func readAdvancedEQ(opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Read.advancedEQ, payload: [], operationID: opID)
    }

    static func setAdvancedEQ(enabled: Bool, opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Write.advancedEQ, payload: [enabled ? 0x01 : 0x00, 0x00], operationID: opID)
    }

    static func readSpatialAudio(opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Read.spatialAudio, payload: [], operationID: opID)
    }

    static func setSpatialAudio(_ mode: SpatialAudioMode, opID: UInt8) -> EarFrame {
        let (first, second) = mode.wireValue
        return EarFrame(command: EarCommand.Write.spatialAudio, payload: [first, second], operationID: opID)
    }

    static func readInEarDetection(opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Read.inEarDetection, payload: [], operationID: opID)
    }

    static func setInEarDetection(_ enabled: Bool, opID: UInt8) -> EarFrame {
        EarFrame(command: EarCommand.Write.inEarDetection, payload: [0x01, 0x01, enabled ? 0x01 : 0x00], operationID: opID)
    }
}
