import XCTest

/// Mock-based tests for SMC reader. Validates that the reader logic decodes
/// FPE2 / sp78 / ui8 / ui16 correctly, given pre-canned bytes.
final class SMCReaderMockTests: XCTestCase {
    /// Local mirror of decode logic to test in isolation.
    enum Decoder {
        static func decodeFPE2(_ bytes: [UInt8]) -> Double {
            guard bytes.count >= 2 else { return 0 }
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(raw) / 4.0
        }
        static func decodeSP78(_ bytes: [UInt8]) -> Double {
            guard bytes.count >= 2 else { return 0 }
            let i16 = Int16(bitPattern: (UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
            return Double(i16) / 256.0
        }
        static func decodeUI16(_ bytes: [UInt8]) -> Double {
            guard bytes.count >= 2 else { return 0 }
            return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
        }
    }

    func testFPE2DecodesRPM4500() {
        // 4500 RPM × 4 = 18000 = 0x4650
        let bytes: [UInt8] = [0x46, 0x50]
        XCTAssertEqual(Decoder.decodeFPE2(bytes), 4500.0, accuracy: 0.5)
    }

    func testFPE2DecodesRPMZero() {
        XCTAssertEqual(Decoder.decodeFPE2([0, 0]), 0.0, accuracy: 0.01)
    }

    func testSP78DecodesTemp50C() {
        // 50.0 × 256 = 12800 = 0x3200
        let bytes: [UInt8] = [0x32, 0x00]
        XCTAssertEqual(Decoder.decodeSP78(bytes), 50.0, accuracy: 0.01)
    }

    func testSP78DecodesNegativeTemp() {
        // -10°C × 256 = -2560 -> Int16 bit pattern 0xF600
        let bytes: [UInt8] = [0xF6, 0x00]
        XCTAssertEqual(Decoder.decodeSP78(bytes), -10.0, accuracy: 0.01)
    }

    func testUI16DecodesMaxFanSpeed() {
        // 6500 RPM if stored as raw uint16 = 0x1964
        let bytes: [UInt8] = [0x19, 0x64]
        XCTAssertEqual(Decoder.decodeUI16(bytes), 6500.0, accuracy: 0.5)
    }
}
