import XCTest
@testable import earmac

final class EarResponseTests: XCTestCase {

    func testParseBatteryResponse() {
        let bytes: [UInt8] = [
            0x55, 0x60, 0x01,
            0x01, 0xE0,
            0x07,
            0x00, 0x01,
            0x03,
            0x02, 0x64,
            0x03, 0x5A,
            0x04, 0x82
        ]

        let response = EarResponse(bytes)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.command, EarCommand.Response.batteryA)

        let battery = response?.parseBattery()
        XCTAssertNotNil(battery)
        XCTAssertEqual(battery?.leftBud.level, 100)
        XCTAssertFalse(battery?.leftBud.isCharging ?? true)
        XCTAssertTrue(battery?.leftBud.isConnected ?? false)

        XCTAssertEqual(battery?.rightBud.level, 90)
        XCTAssertFalse(battery?.rightBud.isCharging ?? true)

        XCTAssertEqual(battery?.caseBattery.level, 2)
        XCTAssertTrue(battery?.caseBattery.isCharging ?? false)
    }

    func testParseBatteryWithCRC() {
        var bytes: [UInt8] = [
            0x55, 0x60, 0x01,
            0x07, 0x40,
            0x07,
            0x00, 0x01,
            0x03,
            0x02, 0x50,
            0x03, 0x50,
            0x04, 0x00
        ]
        let crc = CRC16.calculate(bytes)
        bytes.append(UInt8(crc & 0xFF))
        bytes.append(UInt8((crc >> 8) & 0xFF))

        let response = EarResponse(bytes)
        XCTAssertNotNil(response, "Response with valid header+payload CRC should parse")
        XCTAssertEqual(response?.command, EarCommand.Response.batteryB)

        let battery = response?.parseBattery()
        XCTAssertEqual(battery?.leftBud.level, 80)
        XCTAssertEqual(battery?.rightBud.level, 80)
        XCTAssertFalse(battery?.caseBattery.isConnected ?? true)
    }

    func testParseANCResponse() {
        let bytes: [UInt8] = [
            0x55, 0x60, 0x01,
            0x1E, 0x40,
            0x02,
            0x00, 0x01,
            0x01, 0x01
        ]

        let response = EarResponse(bytes)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.command, EarCommand.Response.ancB)

        let mode = response?.parseANCMode()
        XCTAssertEqual(mode, .high)
    }

    func testParseANCAllModes() {
        let modes: [(UInt8, ANCMode)] = [
            (0x05, .off),
            (0x07, .transparent),
            (0x03, .low),
            (0x02, .mid),
            (0x01, .high),
            (0x04, .adaptive),
        ]

        for (wireValue, expectedMode) in modes {
            let bytes: [UInt8] = [
                0x55, 0x60, 0x01,
                0x03, 0xE0,
                0x02,
                0x00, 0x01,
                0x01, wireValue
            ]
            let response = EarResponse(bytes)
            XCTAssertEqual(response?.parseANCMode(), expectedMode, "ANC wire value 0x\(String(wireValue, radix: 16)) should map to \(expectedMode)")
        }
    }

    func testParseFirmwareVersion() {
        let fwString = "1.6700.2"
        let payload = Array(fwString.utf8)
        var bytes: [UInt8] = [
            0x55, 0x60, 0x01,
            0x42, 0x40,
            UInt8(payload.count),
            0x00, 0x01,
        ]
        bytes.append(contentsOf: payload)

        let response = EarResponse(bytes)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.command, EarCommand.Response.firmware)
        XCTAssertEqual(response?.parseFirmwareVersion(), fwString)
    }

    func testParseSerialNumber() {
        let configText = "0,4,SH54X12345678\n1,6,AABBCCDDEEFF\n"
        let payload = Array(configText.utf8)
        var bytes: [UInt8] = [
            0x55, 0x60, 0x01,
            0x06, 0x40,
            UInt8(payload.count),
            0x00, 0x01,
        ]
        bytes.append(contentsOf: payload)

        let response = EarResponse(bytes)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.command, EarCommand.Response.serialNumber)
        XCTAssertEqual(response?.parseSerialNumber(), "SH54X12345678")
    }

    func testInvalidResponseRejected() {
        let bytes: [UInt8] = [0x00, 0x01, 0x02, 0x03]
        let response = EarResponse(bytes)
        XCTAssertNil(response, "Invalid data should not parse")
    }

    func testResponseWithPayloadOnlyCRC() {
        let payload: [UInt8] = [0x01, 0x01]
        var bytes: [UInt8] = [
            0x55, 0x60, 0x01,
            0x03, 0xE0,
            UInt8(payload.count),
            0x00, 0x01,
        ]
        bytes.append(contentsOf: payload)

        let payloadCRC = CRC16.calculate(payload)
        bytes.append(UInt8(payloadCRC & 0xFF))
        bytes.append(UInt8((payloadCRC >> 8) & 0xFF))

        let response = EarResponse(bytes)
        XCTAssertNotNil(response, "Response with payload-only CRC (CMF Buds Pro 2 quirk) should parse")
        XCTAssertEqual(response?.parseANCMode(), .high)
    }
}
