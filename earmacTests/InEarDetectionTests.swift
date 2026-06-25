import XCTest
@testable import earmac

final class InEarDetectionTests: XCTestCase {

    func testParseInEarDetectionEnabled() {
        let bytes: [UInt8] = [
            0x55, 0x60, 0x01,
            0x0E, 0x40,
            0x03,
            0x00, 0x01,
            0x01, 0x01, 0x01
        ]
        let response = EarResponse(bytes)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.parseInEarDetection(), true)
    }

    func testParseInEarDetectionDisabled() {
        let bytes: [UInt8] = [
            0x55, 0x60, 0x01,
            0x0E, 0x40,
            0x03,
            0x00, 0x01,
            0x01, 0x01, 0x00
        ]
        let response = EarResponse(bytes)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.parseInEarDetection(), false)
    }

    func testParseInEarDetectionTooShort() {
        let bytes: [UInt8] = [
            0x55, 0x60, 0x01,
            0x0E, 0x40,
            0x01,
            0x00, 0x01,
            0x01
        ]
        let response = EarResponse(bytes)
        XCTAssertNotNil(response)
        XCTAssertNil(response?.parseInEarDetection())
    }

    func testCMFBudsPro2SupportsInEarDetection() {
        XCTAssertTrue(DeviceModel.cmfBudsPro2.supportsInEarDetection)
    }

    func testEarOpenDoesNotSupportInEarDetection() {
        XCTAssertFalse(DeviceModel.earOpen.supportsInEarDetection)
    }

    func testSetInEarDetectionRequestPayload() {
        let frame = EarRequest.setInEarDetection(true, opID: 1)
        let bytes = frame.encoded()
        XCTAssertEqual(bytes[8], 0x01, "Payload[0] = 0x01")
        XCTAssertEqual(bytes[9], 0x01, "Payload[1] = 0x01")
        XCTAssertEqual(bytes[10], 0x01, "Payload[2] = enabled = 0x01")
    }

    func testSetInEarDetectionDisabledPayload() {
        let frame = EarRequest.setInEarDetection(false, opID: 1)
        let bytes = frame.encoded()
        XCTAssertEqual(bytes[10], 0x00, "Payload[2] = disabled = 0x00")
    }
}
