import XCTest
@testable import earmac

final class EarFrameTests: XCTestCase {

    func testReadBatteryEncoding() {
        let frame = EarRequest.readBattery(opID: 1)
        let bytes = frame.encoded()

        XCTAssertEqual(bytes.count, 10, "Battery read with empty payload should be 8 header + 2 CRC")

        XCTAssertEqual(bytes[0], 0x55, "Magic byte")
        XCTAssertEqual(bytes[1], 0x60, "Fixed byte")
        XCTAssertEqual(bytes[2], 0x01, "Fixed byte")
        XCTAssertEqual(bytes[3], 0x07, "Command low byte (0xC007 & 0xFF)")
        XCTAssertEqual(bytes[4], 0xC0, "Command high byte (0xC007 >> 8)")
        XCTAssertEqual(bytes[5], 0x00, "Payload length = 0")
        XCTAssertEqual(bytes[6], 0x00, "Reserved byte")
        XCTAssertEqual(bytes[7], 0x01, "Operation ID")
        XCTAssertEqual(bytes[8], 0xAC, "CRC low byte")
        XCTAssertEqual(bytes[9], 0xDF, "CRC high byte")
    }

    func testSetANCEncoding() {
        let frame = EarRequest.setANC(.high, opID: 2)
        let bytes = frame.encoded()

        XCTAssertEqual(bytes.count, 13, "ANC write with 3-byte payload should be 8 header + 3 payload + 2 CRC")

        XCTAssertEqual(bytes[0], 0x55)
        XCTAssertEqual(bytes[1], 0x60)
        XCTAssertEqual(bytes[2], 0x01)
        XCTAssertEqual(bytes[3], 0x0F, "Command low (0xF00F & 0xFF)")
        XCTAssertEqual(bytes[4], 0xF0, "Command high (0xF00F >> 8)")
        XCTAssertEqual(bytes[5], 0x03, "Payload length = 3")
        XCTAssertEqual(bytes[6], 0x00)
        XCTAssertEqual(bytes[7], 0x02, "Operation ID = 2")
        XCTAssertEqual(bytes[8], 0x01, "Payload[0]")
        XCTAssertEqual(bytes[9], 0x01, "Payload[1] = ANC high wire value")
        XCTAssertEqual(bytes[10], 0x00, "Payload[2]")
        XCTAssertEqual(bytes[11], 0xF9, "CRC low")
        XCTAssertEqual(bytes[12], 0x93, "CRC high")
    }

    func testRoundTripThroughEarResponse() {
        let frame = EarRequest.readBattery(opID: 5)
        let bytes = frame.encoded()

        let response = EarResponse(bytes)
        XCTAssertNotNil(response, "Encoded frame should be parseable as a response")
        XCTAssertEqual(response?.command, EarCommand.Read.battery)
        XCTAssertEqual(response?.operationID, 5)
        XCTAssertEqual(response?.payload, [])
    }

    func testOperationIDWrapsAt250() {
        let frame1 = EarFrame(command: 0xC007, payload: [], operationID: 250)
        let frame2 = EarFrame(command: 0xC007, payload: [], operationID: 1)

        XCTAssertEqual(frame1.encoded()[7], 250)
        XCTAssertEqual(frame2.encoded()[7], 1)
    }
}
