import Foundation

enum EarCommand: Sendable {

    enum Read {
        static let battery: UInt16      = 0xC007
        static let serialNumber: UInt16 = 0xC006
        static let firmware: UInt16     = 0xC042
        static let anc: UInt16          = 0xC01E
    }

    enum Write {
        static let anc: UInt16          = 0xF00F
    }

    enum Response {
        static let batteryA: UInt16      = 0xE001
        static let batteryB: UInt16      = 0x4007
        static let serialNumber: UInt16  = 0x4006
        static let firmware: UInt16      = 0x4042
        static let ancA: UInt16          = 0xE003
        static let ancB: UInt16          = 0x401E
    }
}
