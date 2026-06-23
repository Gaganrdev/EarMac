import XCTest
@testable import earmac

final class CRC16Tests: XCTestCase {

    func testStandardCheckValue() {
        let input: [UInt8] = Array("123456789".utf8)
        let result = CRC16.calculate(input)
        XCTAssertEqual(result, 0x4B37, "CRC-16/MODBUS of '123456789' should be 0x4B37")
    }

    func testEmptyInput() {
        let result = CRC16.calculate([])
        XCTAssertEqual(result, 0xFFFF, "CRC of empty data should be initial value 0xFFFF")
    }

    func testSingleByte() {
        let result = CRC16.calculate([0x00])
        XCTAssertEqual(result, 0x40BF, "CRC of [0x00] should be 0x40BF")
    }

    func testBatteryReadHeader() {
        let header: [UInt8] = [0x55, 0x60, 0x01, 0x07, 0xC0, 0x00, 0x00, 0x01]
        let result = CRC16.calculate(header)
        XCTAssertEqual(result, 0xDFAC, "CRC of battery-read header should be 0xDFAC")
    }

    func testANCWriteFrame() {
        let frame: [UInt8] = [0x55, 0x60, 0x01, 0x0F, 0xF0, 0x03, 0x00, 0x02, 0x01, 0x01, 0x00]
        let result = CRC16.calculate(frame)
        XCTAssertEqual(result, 0x93F9, "CRC of ANC-write frame should be 0x93F9")
    }
}
