import XCTest
@testable import earmac

final class SpatialAudioTests: XCTestCase {

    func testTwoByteWireValues() {
        XCTAssertEqual(SpatialAudioMode.off.wireValue.0, 0x00)
        XCTAssertEqual(SpatialAudioMode.off.wireValue.1, 0x00)
        XCTAssertEqual(SpatialAudioMode.fixed.wireValue.0, 0x01)
        XCTAssertEqual(SpatialAudioMode.fixed.wireValue.1, 0x00)
        XCTAssertEqual(SpatialAudioMode.headTracking.wireValue.0, 0x01)
        XCTAssertEqual(SpatialAudioMode.headTracking.wireValue.1, 0x01)
        XCTAssertEqual(SpatialAudioMode.concert.wireValue.0, 0x02)
        XCTAssertEqual(SpatialAudioMode.concert.wireValue.1, 0x00)
        XCTAssertEqual(SpatialAudioMode.cinema.wireValue.0, 0x03)
        XCTAssertEqual(SpatialAudioMode.cinema.wireValue.1, 0x00)
    }

    func testFromWireBytes() {
        XCTAssertEqual(SpatialAudioMode.fromWireBytes(0x00, 0x00), .off)
        XCTAssertEqual(SpatialAudioMode.fromWireBytes(0x01, 0x00), .fixed)
        XCTAssertEqual(SpatialAudioMode.fromWireBytes(0x01, 0x01), .headTracking)
        XCTAssertEqual(SpatialAudioMode.fromWireBytes(0x02, 0x00), .concert)
        XCTAssertEqual(SpatialAudioMode.fromWireBytes(0x03, 0x00), .cinema)
        XCTAssertNil(SpatialAudioMode.fromWireBytes(0xFF, 0xFF))
    }

    func testFromSingleByte() {
        XCTAssertEqual(SpatialAudioMode.fromSingleByte(0x00), .off)
        XCTAssertEqual(SpatialAudioMode.fromSingleByte(0x01), .fixed)
        XCTAssertEqual(SpatialAudioMode.fromSingleByte(0x02), .headTracking)
        XCTAssertNil(SpatialAudioMode.fromSingleByte(0x03))
    }

    func testCMFBudsPro2SupportedModes() {
        let modes = DeviceModel.cmfBudsPro2.supportedSpatialAudioModes
        XCTAssertEqual(modes, [.off, .fixed])
    }

    func testCMFBudsPro2SupportsSpatialAudio() {
        XCTAssertTrue(DeviceModel.cmfBudsPro2.supportsSpatialAudio)
        XCTAssertFalse(DeviceModel.ear1.supportsSpatialAudio)
    }

    func testParseSpatialAudioResponseTwoByte() {
        let bytes: [UInt8] = [
            0x55, 0x60, 0x01,
            0x4F, 0x40,
            0x02,
            0x00, 0x01,
            0x01, 0x00
        ]
        let response = EarResponse(bytes)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.parseSpatialAudioMode(), .fixed)
    }

    func testParseSpatialAudioResponseSingleByte() {
        let bytes: [UInt8] = [
            0x55, 0x60, 0x01,
            0x4F, 0x40,
            0x01,
            0x00, 0x01,
            0x01
        ]
        let response = EarResponse(bytes)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.parseSpatialAudioMode(), .fixed)
    }
}
