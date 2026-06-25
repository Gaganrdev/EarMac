import Foundation

struct EQPresetCustom: Sendable, Equatable {
    let bass: Int
    let mid: Int
    let treble: Int

    init(bass: Int, mid: Int, treble: Int) {
        self.bass = max(-6, min(6, bass))
        self.mid = max(-6, min(6, mid))
        self.treble = max(-6, min(6, treble))
    }

    static let flat = EQPresetCustom(bass: 0, mid: 0, treble: 0)
}

struct EQPresetCustomSpecs: Sendable, Equatable {
    let freqLow: Float
    let qLow: Float
    let freqPeak: Float
    let qPeak: Float
    let freqHigh: Float
    let qHigh: Float

    static let defaultSpecs = EQPresetCustomSpecs(
        freqLow: 140.0, qLow: 0.8,
        freqPeak: 980.0, qPeak: 0.7,
        freqHigh: 3400.0, qHigh: 1.0
    )
}

extension EQPresetCustom {

    func encodedPayload(specs: EQPresetCustomSpecs) -> [UInt8] {
        func floatBytes(_ value: Float) -> [UInt8] {
            let raw = value.bitPattern.littleEndian
            return [
                UInt8(raw & 0xFF),
                UInt8((raw >> 8) & 0xFF),
                UInt8((raw >> 16) & 0xFF),
                UInt8((raw >> 24) & 0xFF)
            ]
        }

        struct Band {
            let filterType: UInt8
            let gain: Float
            let frequency: Float
            let quality: Float
        }

        let bands: [Band] = [
            Band(filterType: 0x01, gain: Float(mid), frequency: specs.freqPeak, quality: specs.qPeak),
            Band(filterType: 0x02, gain: Float(treble), frequency: specs.freqHigh, quality: specs.qHigh),
            Band(filterType: 0x00, gain: Float(bass), frequency: specs.freqLow, quality: specs.qLow),
        ]

        var maxGain: Float = 0.0
        for band in bands where band.gain > maxGain {
            maxGain = band.gain
        }
        let totalGain = -maxGain

        let packetSize = 1 + 4 + (bands.count * 13) + (bands.count * 3)
        var packet = [UInt8](repeating: 0, count: packetSize)
        var offset = 0

        packet[offset] = UInt8(bands.count)
        offset += 1

        let totalGainBytes = floatBytes(totalGain)
        packet[offset..<(offset + 4)] = totalGainBytes[0..<4]
        offset += 4

        for band in bands {
            packet[offset] = band.filterType
            offset += 1

            let gainBytes = floatBytes(band.gain)
            packet[offset..<(offset + 4)] = gainBytes[0..<4]
            offset += 4

            let freqBytes = floatBytes(band.frequency)
            packet[offset..<(offset + 4)] = freqBytes[0..<4]
            offset += 4

            let qBytes = floatBytes(band.quality)
            packet[offset..<(offset + 4)] = qBytes[0..<4]
            offset += 4
        }

        for _ in bands {
            packet[offset] = 0x00
            packet[offset + 1] = 0x00
            packet[offset + 2] = 0x00
            offset += 3
        }

        return packet
    }
}
