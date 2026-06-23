import Foundation

struct EarFrame: Sendable, Equatable {

    static let headerPrefix: [UInt8] = [0x55, 0x60, 0x01]
    static let headerSize = 8

    let command: UInt16
    let payload: [UInt8]
    let operationID: UInt8

    func encoded() -> [UInt8] {
        var bytes = Self.headerPrefix
        bytes.append(UInt8(command & 0xFF))
        bytes.append(UInt8((command >> 8) & 0xFF))
        bytes.append(UInt8(payload.count))
        bytes.append(0x00)
        bytes.append(operationID)
        bytes.append(contentsOf: payload)
        let crc = CRC16.calculate(bytes)
        bytes.append(UInt8(crc & 0xFF))
        bytes.append(UInt8((crc >> 8) & 0xFF))
        return bytes
    }
}
