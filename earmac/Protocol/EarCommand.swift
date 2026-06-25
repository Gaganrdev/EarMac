import Foundation

enum EarCommand: Sendable {

    enum Read {
        static let battery: UInt16         = 0xC007
        static let serialNumber: UInt16    = 0xC006
        static let firmware: UInt16        = 0xC042
        static let anc: UInt16             = 0xC01E
        static let eq: UInt16              = 0xC01F
        static let listeningMode: UInt16   = 0xC050
        static let customEQ: UInt16        = 0xC044
        static let advancedEQ: UInt16      = 0xC04C
        static let spatialAudio: UInt16    = 0xC04F
        static let inEarDetection: UInt16  = 0xC00E
    }

    enum Write {
        static let anc: UInt16             = 0xF00F
        static let eq: UInt16              = 0xF010
        static let listeningMode: UInt16   = 0xF01D
        static let customEQ: UInt16        = 0xF041
        static let advancedEQ: UInt16      = 0xF06F
        static let spatialAudio: UInt16    = 0xF052
        static let inEarDetection: UInt16  = 0xF004
    }

    enum Response {
        static let batteryA: UInt16        = 0xE001
        static let batteryB: UInt16        = 0x4007
        static let serialNumber: UInt16    = 0x4006
        static let firmware: UInt16        = 0x4042
        static let ancA: UInt16            = 0xE003
        static let ancB: UInt16            = 0x401E
        static let eqA: UInt16             = 0x401F
        static let eqB: UInt16             = 0x4040
        static let listeningMode: UInt16   = 0x4050
        static let customEQ: UInt16        = 0x4044
        static let advancedEQ: UInt16      = 0x404C
        static let advancedEQWrite: UInt16 = 0x706F
        static let spatialAudio: UInt16    = 0x404F
        static let inEarDetection: UInt16  = 0x400E
    }
}
