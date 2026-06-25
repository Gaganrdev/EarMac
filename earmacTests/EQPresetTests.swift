import XCTest
@testable import earmac

final class EQPresetTests: XCTestCase {

    func testWireValueRoundTrip() {
        for preset in EQPreset.allCases {
            let wire = preset.wireValue
            let restored = EQPreset.fromWireValue(wire)
            XCTAssertEqual(restored, preset, "Round-trip failed for \(preset.displayName)")
        }
    }

    func testSpecificWireValues() {
        XCTAssertEqual(EQPreset.balanced.wireValue, 0x00)
        XCTAssertEqual(EQPreset.voice.wireValue, 0x01)
        XCTAssertEqual(EQPreset.moreTreble.wireValue, 0x02)
        XCTAssertEqual(EQPreset.moreBass.wireValue, 0x03)
        XCTAssertEqual(EQPreset.custom.wireValue, 0x05)
        XCTAssertEqual(EQPreset.advanced.wireValue, 0x06)
    }

    func testInvalidWireValue() {
        XCTAssertNil(EQPreset.fromWireValue(0x04))
        XCTAssertNil(EQPreset.fromWireValue(0xFF))
    }
}
