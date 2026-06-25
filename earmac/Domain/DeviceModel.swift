import Foundation

enum DeviceModel: Sendable, Equatable {
    case ear1
    case earStick
    case ear2
    case ear3
    case earOpen
    case ear
    case earA
    case cmfBudsPro
    case cmfBuds
    case cmfBudsPro2
    case cmfBuds2
    case cmfBuds2Plus
    case cmfBuds2a
    case cmfNeckbandPro
    case headphone1
    case headphoneA
    case cmfHeadphonePro
    case unknown

    var displayName: String {
        switch self {
        case .ear1:             return "Nothing Ear (1)"
        case .earStick:         return "Nothing Ear (stick)"
        case .ear2:             return "Nothing Ear (2)"
        case .ear3:             return "Nothing Ear (3)"
        case .earOpen:          return "Nothing Ear (open)"
        case .ear:              return "Nothing Ear"
        case .earA:             return "Nothing Ear (a)"
        case .cmfBudsPro:       return "CMF Buds Pro"
        case .cmfBuds:          return "CMF Buds"
        case .cmfBudsPro2:      return "CMF Buds Pro 2"
        case .cmfBuds2:         return "CMF Buds 2"
        case .cmfBuds2Plus:     return "CMF Buds 2 Plus"
        case .cmfBuds2a:        return "CMF Buds 2a"
        case .cmfNeckbandPro:   return "CMF Neckband Pro"
        case .headphone1:       return "Nothing Headphone (1)"
        case .headphoneA:       return "Nothing Headphone (a)"
        case .cmfHeadphonePro:  return "CMF Headphone Pro"
        case .unknown:          return "Unknown Device"
        }
    }

    var code: String {
        switch self {
        case .ear1:             return "B181"
        case .earStick:         return "B157"
        case .ear2:             return "B155"
        case .ear3:             return "B173"
        case .earOpen:          return "B174"
        case .ear:              return "B171"
        case .earA:             return "B162"
        case .cmfBudsPro:       return "B163"
        case .cmfBuds:          return "B168"
        case .cmfBudsPro2:      return "B172"
        case .cmfBuds2:         return "B179"
        case .cmfBuds2Plus:     return "B184"
        case .cmfBuds2a:        return "B185"
        case .cmfNeckbandPro:   return "B164"
        case .headphone1:       return "B170"
        case .headphoneA:       return "B186"
        case .cmfHeadphonePro:  return "B175"
        case .unknown:          return "B???"
        }
    }

    var supportsANC: Bool {
        switch self {
        case .ear1, .ear2, .ear3, .ear, .cmfBudsPro, .cmfBudsPro2, .cmfBuds2,
             .cmfBuds2Plus, .cmfNeckbandPro, .headphone1, .headphoneA, .cmfHeadphonePro:
            return true
        default:
            return false
        }
    }

    var supportsSpatialAudio: Bool {
        switch self {
        case .ear3, .headphone1, .headphoneA, .cmfBuds2, .cmfBuds2Plus,
             .cmfBudsPro2, .cmfNeckbandPro, .cmfHeadphonePro:
            return true
        default:
            return false
        }
    }

    var supportedSpatialAudioModes: [SpatialAudioMode] {
        switch self {
        case .headphone1, .headphoneA:
            return [.off, .fixed, .headTracking]
        case .ear3, .cmfBuds2, .cmfBuds2Plus, .cmfBudsPro2, .cmfNeckbandPro:
            return [.off, .fixed]
        case .cmfHeadphonePro:
            return [.off, .cinema, .concert]
        default:
            return []
        }
    }

    var supportsEQ: Bool {
        switch self {
        case .unknown: return false
        default: return true
        }
    }

    var supportsCustomEQ: Bool {
        self != .ear1 && self != .unknown
    }

    var supportsAdvancedEQ: Bool {
        self != .cmfNeckbandPro && self != .unknown
    }

    var supportsInEarDetection: Bool {
        self != .earOpen && self != .unknown
    }

    var supportsListeningMode: Bool {
        switch self {
        case .cmfBuds, .cmfBuds2a, .cmfBuds2, .cmfBuds2Plus, .cmfBudsPro2:
            return true
        default:
            return false
        }
    }

    var eqPresetCustomSpecs: EQPresetCustomSpecs {
        switch self {
        case .headphone1, .headphoneA, .cmfHeadphonePro:
            return EQPresetCustomSpecs(freqLow: 140.0, qLow: 0.8, freqPeak: 980.0, qPeak: 0.7, freqHigh: 3500.0, qHigh: 1.0)
        case .earStick:
            return EQPresetCustomSpecs(freqLow: 140.0, qLow: 0.8, freqPeak: 980.0, qPeak: 0.66, freqHigh: 3500.0, qHigh: 1.0)
        case .ear1, .ear2, .ear3, .earOpen, .ear, .earA, .cmfBudsPro:
            return EQPresetCustomSpecs(freqLow: 140.0, qLow: 0.8, freqPeak: 980.0, qPeak: 0.7, freqHigh: 3400.0, qHigh: 1.0)
        case .cmfBuds, .cmfBuds2a, .cmfBuds2, .cmfBuds2Plus, .cmfBudsPro2, .cmfNeckbandPro:
            return EQPresetCustomSpecs(freqLow: 140.0, qLow: 0.8, freqPeak: 980.0, qPeak: 0.7, freqHigh: 6900.0, qHigh: 1.0)
        case .unknown:
            return .defaultSpecs
        }
    }

    static func detect(deviceName: String, serialNumber: String) -> DeviceModel {
        if let model = detectFromSerial(serialNumber) {
            return model
        }
        return detectFromName(deviceName)
    }

    static func detectFromName(_ name: String) -> DeviceModel {
        switch name {
        case "Nothing ear (1)":      return .ear1
        case "Ear (Stick)":          return .earStick
        case "Ear (2)":              return .ear2
        case "Nothing Ear":          return .ear
        case "Nothing Ear (a)":      return .earA
        case "Nothing Ear (open)":   return .earOpen
        case "Buds Pro":             return .cmfBudsPro
        case "Neckband Pro":         return .cmfNeckbandPro
        case "CMF Buds":             return .cmfBuds
        case "CMF Buds Pro 2":       return .cmfBudsPro2
        case "CMF Buds 2":           return .cmfBuds2
        case "CMF Buds 2 Plus":      return .cmfBuds2Plus
        case "CMF Buds 2a":          return .cmfBuds2a
        case "Nothing Headphone (1)": return .headphone1
        case "Nothing Ear (3)":      return .ear3
        case "CMF Headphone Pro":    return .cmfHeadphonePro
        case "Nothing Headphone (a)": return .headphoneA
        default:                     return .unknown
        }
    }

    static func detectFromSerial(_ serial: String) -> DeviceModel? {
        guard serial.count >= 8 else { return nil }

        let prefix = String(serial.prefix(2))
        let sku: String

        switch prefix {
        case "SH", "13":
            guard serial.count >= 6 else { return nil }
            let start = serial.index(serial.startIndex, offsetBy: 4)
            let end = serial.index(start, offsetBy: 2)
            sku = String(serial[start..<end])

        case "M3":
            guard serial.count >= 6 else { return nil }
            let start = serial.index(serial.startIndex, offsetBy: 3)
            let end = serial.index(start, offsetBy: 3)
            sku = String(serial[start..<end])

        case "MA":
            let yearStart = serial.index(serial.startIndex, offsetBy: 6)
            let yearEnd = serial.index(yearStart, offsetBy: 2)
            let year = String(serial[yearStart..<yearEnd])
            if year == "22" || year == "23" {
                sku = "14"
            } else {
                sku = ""
            }

        default:
            sku = ""
        }

        return detectFromSKU(sku)
    }

    static func detectFromSKU(_ sku: String) -> DeviceModel? {
        switch sku {
        case "01", "02", "03", "04", "06", "07", "08", "10":
            return .ear1
        case "14", "15", "16":
            return .earStick
        case "17", "18", "19", "27", "28", "29":
            return .ear2
        case "25", "26":
            return .ear3
        case "30", "31", "32", "33", "34", "35":
            return .cmfBudsPro
        case "48", "49", "50", "51", "52", "53":
            return .cmfNeckbandPro
        case "54", "55", "56", "57", "58", "59":
            return .cmfBuds
        case "99":
            return .cmfBuds2
        case "61", "62", "69", "70", "74", "75":
            return .ear
        case "63", "64", "65", "66", "67", "68", "71", "72", "73":
            return .earA
        case "76", "77", "78", "79", "80", "81", "82", "83":
            return .cmfBudsPro2
        case "603", "606":
            return .headphone1
        case "84", "85", "86", "87", "88", "89":
            return .cmfHeadphonePro
        default:
            return nil
        }
    }
}
