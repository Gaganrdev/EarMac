import XCTest
@testable import earmac

final class CustomEQTests: XCTestCase {

    func testClamping() {
        let custom = EQPresetCustom(bass: 10, mid: -10, treble: 3)
        XCTAssertEqual(custom.bass, 6, "Bass should be clamped to 6")
        XCTAssertEqual(custom.mid, -6, "Mid should be clamped to -6")
        XCTAssertEqual(custom.treble, 3, "Treble should remain 3")
    }

    func testFlatPreset() {
        XCTAssertEqual(EQPresetCustom.flat.bass, 0)
        XCTAssertEqual(EQPresetCustom.flat.mid, 0)
        XCTAssertEqual(EQPresetCustom.flat.treble, 0)
    }

    func testPayloadSize() {
        let custom = EQPresetCustom(bass: 3, mid: -2, treble: 1)
        let payload = custom.encodedPayload(specs: .defaultSpecs)
        XCTAssertEqual(payload.count, 53, "Custom EQ payload should be 53 bytes")
    }

    func testPayloadFirstByteIsBandCount() {
        let custom = EQPresetCustom(bass: 1, mid: 0, treble: -1)
        let payload = custom.encodedPayload(specs: .defaultSpecs)
        XCTAssertEqual(payload[0], 3, "First byte should be band count (3)")
    }

    func testPayloadTotalGainOffset() {
        let custom = EQPresetCustom(bass: 0, mid: 0, treble: 0)
        let payload = custom.encodedPayload(specs: .defaultSpecs)

        // Total gain for flat EQ is -0.0 (negative of max gain 0.0)
        // Float(-0.0) bitPattern = 0x80000000
        // Little-endian: 0x00, 0x00, 0x00, 0x80
        XCTAssertEqual(payload[1], 0x00)
        XCTAssertEqual(payload[2], 0x00)
        XCTAssertEqual(payload[3], 0x00)
        XCTAssertEqual(payload[4], 0x80)
    }

    func testPayloadWithPositiveGain() {
        let custom = EQPresetCustom(bass: 5, mid: 0, treble: 0)
        let payload = custom.encodedPayload(specs: .defaultSpecs)

        // Total gain should be -5.0 (negative of max gain)
        // Float(-5.0) bitPattern = 0xC0A00000
        // Little-endian: 0x00, 0x00, 0xA0, 0xC0
        XCTAssertEqual(payload[1], 0x00)
        XCTAssertEqual(payload[2], 0x00)
        XCTAssertEqual(payload[3], 0xA0)
        XCTAssertEqual(payload[4], 0xC0)
    }

    func testSpecsForCMFBudsPro2() {
        let specs = DeviceModel.cmfBudsPro2.eqPresetCustomSpecs
        XCTAssertEqual(specs.freqHigh, 6900.0)
        XCTAssertEqual(specs.freqPeak, 980.0)
        XCTAssertEqual(specs.freqLow, 140.0)
    }

    func testParseCustomEQRoundTrip() {
        let original = EQPresetCustom(bass: 5, mid: -3, treble: 2)
        let payload = original.encodedPayload(specs: .defaultSpecs)

        var bytes: [UInt8] = [
            0x55, 0x60, 0x01,
            0x44, 0x40,
            UInt8(payload.count),
            0x00, 0x01,
        ]
        bytes.append(contentsOf: payload)

        let response = EarResponse(bytes)
        XCTAssertNotNil(response)
        let parsed = response?.parseCustomEQ()
        XCTAssertEqual(parsed?.bass, 5, "Bass should round-trip correctly")
        XCTAssertEqual(parsed?.mid, -3, "Mid should round-trip correctly")
        XCTAssertEqual(parsed?.treble, 2, "Treble should round-trip correctly")
    }
}
