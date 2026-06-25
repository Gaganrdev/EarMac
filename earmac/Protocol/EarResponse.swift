import Foundation

struct EarResponse: Sendable, Equatable {

    let command: UInt16
    let payload: [UInt8]
    let operationID: UInt8

    init?(_ data: [UInt8]) {
        guard data.count >= 8, data[0] == 0x55 else {
            return nil
        }

        let payloadLength = Int(data[5])
        let hasCRC = data.count >= 8 + payloadLength + 2
        let requiredLength = 8 + payloadLength + (hasCRC ? 2 : 0)

        guard data.count >= requiredLength else {
            return nil
        }

        command = UInt16(data[3]) | (UInt16(data[4]) << 8)
        operationID = data[7]
        payload = Array(data[8..<(8 + payloadLength)])

        if hasCRC {
            let crcIndex = 8 + payloadLength
            let receivedCRC = UInt16(data[crcIndex]) | (UInt16(data[crcIndex + 1]) << 8)

            let fullCRC = CRC16.calculate(Array(data[0..<crcIndex]))
            if receivedCRC != fullCRC {
                let payloadOnlyCRC = CRC16.calculate(Array(data[8..<crcIndex]))
                guard receivedCRC == payloadOnlyCRC else {
                    return nil
                }
            }
        }
    }
}

extension EarResponse {

    func parseBattery() -> BatteryInfo? {
        guard payload.count >= 1 else {
            return nil
        }

        let connectedCount = Int(payload[0])
        let expectedLength = 1 + (connectedCount * 2)

        guard payload.count >= expectedLength else {
            return nil
        }

        var entries: [UInt8: BatteryLevel] = [:]

        for i in 0..<connectedCount {
            let deviceID = payload[1 + (i * 2)]
            let raw = payload[2 + (i * 2)]
            let level = Int(raw & 0x7F)
            let isCharging = (raw & 0x80) != 0
            entries[deviceID] = BatteryLevel(
                level: level,
                isCharging: isCharging,
                isConnected: level > 0 || isCharging
            )
        }

        return BatteryInfo(
            caseBattery: entries[0x04] ?? .disconnected,
            leftBud: entries[0x02] ?? .disconnected,
            rightBud: entries[0x03] ?? .disconnected
        )
    }

    func parseFirmwareVersion() -> String {
        String(bytes: payload, encoding: .utf8) ?? ""
    }

    func parseSerialNumber() -> String? {
        for entry in parseConfigEntries() where entry.type == 4 {
            return entry.value
        }
        return nil
    }

    func parseANCMode() -> ANCMode? {
        guard payload.count >= 2 else {
            return nil
        }
        return ANCMode.fromWireValue(payload[1])
    }

    func parseEQPreset() -> EQPreset? {
        if payload.count > 1 {
            return EQPreset.fromWireValue(payload[1])
        } else if payload.count == 1 {
            return EQPreset.fromWireValue(payload[0])
        }
        return nil
    }

    func parseCustomEQ() -> EQPresetCustom? {
        let bassOffset = 6
        let midOffset = 19
        let trebleOffset = 32

        func readFloat(at offset: Int) -> Float? {
            guard payload.count >= offset + 4 else { return nil }
            let raw = UInt32(payload[offset])
                | (UInt32(payload[offset + 1]) << 8)
                | (UInt32(payload[offset + 2]) << 16)
                | (UInt32(payload[offset + 3]) << 24)
            return Float(bitPattern: raw)
        }

        guard let bassValue = readFloat(at: bassOffset),
              let midValue = readFloat(at: midOffset),
              let trebleValue = readFloat(at: trebleOffset)
        else {
            return nil
        }

        func clamp(_ value: Int, _ min: Int, _ max: Int) -> Int {
            Swift.max(min, Swift.min(max, value))
        }

        return EQPresetCustom(
            bass: clamp(Int(bassValue.rounded()), -6, 6),
            mid: clamp(Int(midValue.rounded()), -6, 6),
            treble: clamp(Int(trebleValue.rounded()), -6, 6)
        )
    }

    func parseAdvancedEQ() -> Bool? {
        if payload.isEmpty { return false }
        return payload[0] != 0
    }

    func parseSpatialAudioMode() -> SpatialAudioMode? {
        guard !payload.isEmpty else { return nil }

        if payload.count == 1 {
            switch payload[0] {
            case 0x00: return .off
            case 0x01: return .fixed
            case 0x02: return .headTracking
            default: return nil
            }
        }

        let first = payload[0]
        let second = payload[1]

        switch (first, second) {
        case (0x00, 0x00): return .off
        case (0x01, 0x00): return .fixed
        case (0x01, 0x01): return .headTracking
        case (0x02, 0x00): return .concert
        case (0x03, 0x00): return .cinema
        default: return nil
        }
    }

    func parseInEarDetection() -> Bool? {
        guard payload.count >= 3 else { return nil }
        return payload[2] != 0
    }

    private func parseConfigEntries() -> [(index: Int, type: Int, value: String)] {
        let candidates: [[UInt8]] = [
            payload,
            payload.count > 7 ? Array(payload[7...]) : []
        ].filter { !$0.isEmpty }

        for candidate in candidates {
            let sanitized = candidate.filter { byte in
                (byte >= 0x20 && byte < 0x80) || byte == 0x0A || byte == 0x0D
            }

            guard let text = String(bytes: sanitized, encoding: .utf8) else {
                continue
            }

            let entries = text.split(separator: "\n").compactMap { line -> (index: Int, type: Int, value: String)? in
                let parts = line.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
                guard parts.count == 3,
                      let index = Int(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                      let type = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
                else {
                    return nil
                }
                let value = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else {
                    return nil
                }
                return (index, type, value)
            }

            if !entries.isEmpty {
                return entries
            }
        }

        return []
    }
}
