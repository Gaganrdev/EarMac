import Foundation

enum SpatialAudioMode: String, CaseIterable, Sendable, Equatable {
    case off
    case fixed
    case headTracking
    case concert
    case cinema

    var wireValue: (UInt8, UInt8) {
        switch self {
        case .off:           return (0x00, 0x00)
        case .fixed:         return (0x01, 0x00)
        case .headTracking:  return (0x01, 0x01)
        case .concert:       return (0x02, 0x00)
        case .cinema:        return (0x03, 0x00)
        }
    }

    static func fromWireBytes(_ first: UInt8, _ second: UInt8) -> SpatialAudioMode? {
        switch (first, second) {
        case (0x00, 0x00): return .off
        case (0x01, 0x00): return .fixed
        case (0x01, 0x01): return .headTracking
        case (0x02, 0x00): return .concert
        case (0x03, 0x00): return .cinema
        default: return nil
        }
    }

    static func fromSingleByte(_ value: UInt8) -> SpatialAudioMode? {
        switch value {
        case 0x00: return .off
        case 0x01: return .fixed
        case 0x02: return .headTracking
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .off:           return "Off"
        case .fixed:         return "Fixed"
        case .headTracking:  return "Head Tracking"
        case .concert:       return "Concert"
        case .cinema:        return "Cinema"
        }
    }

    var symbolName: String {
        switch self {
        case .off:           return "speaker.slash.fill"
        case .fixed:         return "speaker.wave.3.fill"
        case .headTracking:  return "person.crop.circle.badge.checkmark"
        case .concert:       return "music.mic"
        case .cinema:        return "film.fill"
        }
    }
}
