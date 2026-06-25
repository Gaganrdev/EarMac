import Foundation

enum EQPreset: String, CaseIterable, Sendable, Equatable {
    case balanced
    case voice
    case moreTreble
    case moreBass
    case custom
    case advanced

    var wireValue: UInt8 {
        switch self {
        case .balanced:    return 0x00
        case .voice:        return 0x01
        case .moreTreble:   return 0x02
        case .moreBass:     return 0x03
        case .custom:       return 0x05
        case .advanced:     return 0x06
        }
    }

    static func fromWireValue(_ value: UInt8) -> EQPreset? {
        switch value {
        case 0x00: return .balanced
        case 0x01: return .voice
        case 0x02: return .moreTreble
        case 0x03: return .moreBass
        case 0x05: return .custom
        case 0x06: return .advanced
        default:   return nil
        }
    }

    var displayName: String {
        switch self {
        case .balanced:    return "Balanced"
        case .voice:        return "Voice"
        case .moreTreble:   return "More Treble"
        case .moreBass:     return "More Bass"
        case .custom:       return "Custom"
        case .advanced:     return "Advanced"
        }
    }

    var symbolName: String {
        switch self {
        case .balanced:    return "slider.horizontal.3"
        case .voice:        return "person.wave.2.fill"
        case .moreTreble:   return "music.note.high"
        case .moreBass:     return "music.note.low"
        case .custom:       return "slider.vertical.3"
        case .advanced:     return "waveform.path.ecg"
        }
    }
}
