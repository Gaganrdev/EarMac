import Foundation

enum ANCMode: String, CaseIterable, Sendable, Equatable {
    case off
    case transparent
    case low
    case mid
    case high
    case adaptive

    var wireValue: UInt8 {
        switch self {
        case .off:        return 0x05
        case .transparent: return 0x07
        case .low:         return 0x03
        case .mid:         return 0x02
        case .high:        return 0x01
        case .adaptive:    return 0x04
        }
    }

    static func fromWireValue(_ value: UInt8) -> ANCMode? {
        switch value {
        case 0x05: return .off
        case 0x07: return .transparent
        case 0x03: return .low
        case 0x02: return .mid
        case 0x01: return .high
        case 0x04: return .adaptive
        default:   return nil
        }
    }

    var displayName: String {
        switch self {
        case .off:         return "Off"
        case .transparent: return "Transparency"
        case .low:         return "Low"
        case .mid:         return "Mid"
        case .high:        return "High"
        case .adaptive:    return "Adaptive"
        }
    }

    var symbolName: String {
        switch self {
        case .off:         return "speaker.slash.fill"
        case .transparent: return "ear.fill"
        case .low:         return "speaker.wave.1.fill"
        case .mid:         return "speaker.wave.2.fill"
        case .high:        return "speaker.wave.3.fill"
        case .adaptive:    return "sparkles"
        }
    }

    var group: ANCGroup {
        switch self {
        case .off:         return .off
        case .transparent: return .transparent
        case .low, .mid, .high, .adaptive: return .anc
        }
    }

    static var ancLevels: [ANCMode] {
        [.low, .mid, .high, .adaptive]
    }
}

enum ANCGroup: String, CaseIterable, Sendable, Equatable {
    case off
    case transparent
    case anc

    var displayName: String {
        switch self {
        case .off:         return "Off"
        case .transparent: return "Transparent"
        case .anc:         return "ANC"
        }
    }

    var symbolName: String {
        switch self {
        case .off:         return "speaker.slash.fill"
        case .transparent: return "ear.fill"
        case .anc:         return "speaker.wave.3.fill"
        }
    }
}
