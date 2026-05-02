import XCTest

/// Tests Task 4.5: 4-char SMC key codes encode to UInt32 big-endian.
final class SMCKeyEncodingTests: XCTestCase {
    func testF0AcEncoding() {
        // 'F' = 0x46, '0' = 0x30, 'A' = 0x41, 'c' = 0x63
        let expected: UInt32 = 0x46304163
        let actual = fourCC("F0Ac")
        XCTAssertEqual(actual, expected)
    }

    func testF0TgEncoding() {
        // 'F' = 0x46, '0' = 0x30, 'T' = 0x54, 'g' = 0x67
        XCTAssertEqual(fourCC("F0Tg"), 0x46305467)
    }

    func testTp01Encoding() {
        // 'T' = 0x54, 'p' = 0x70, '0' = 0x30, '1' = 0x31
        XCTAssertEqual(fourCC("Tp01"), 0x54703031)
    }

    func testFNumEncoding() {
        // 'F' = 0x46, 'N' = 0x4E, 'u' = 0x75, 'm' = 0x6D
        XCTAssertEqual(fourCC("FNum"), 0x464E756D)
    }

    private func fourCC(_ s: String) -> UInt32 {
        var result: UInt32 = 0
        for byte in s.utf8 {
            result = (result << 8) | UInt32(byte)
        }
        return result
    }
}
