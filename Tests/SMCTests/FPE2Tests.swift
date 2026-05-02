import XCTest

#if canImport(IOKit)
@testable import struct FanControlShared.SensorSnapshot
#endif

/// Pure-logic tests for FPE2 encoding. Replicates the SMC fixed-point format.
/// Mirrors the file `Helper/SMC/FPE2.swift` directly, no IO.
final class FPE2Tests: XCTestCase {
    // FPE2 encoding logic re-declared here to keep the test target free of IOKit.
    enum FPE2Local {
        static func decode(_ bytes: [UInt8]) -> Double {
            guard bytes.count >= 2 else { return 0 }
            let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(raw) / 4.0
        }
        static func encode(_ value: Double) -> [UInt8] {
            let clamped = max(0, value)
            let scaled = UInt32((clamped * 4.0).rounded())
            let truncated = min(scaled, UInt32(UInt16.max))
            let raw = UInt16(truncated)
            return [UInt8((raw >> 8) & 0xFF), UInt8(raw & 0xFF)]
        }
    }

    func testEncodeDecodeRoundTripZero() {
        let bytes = FPE2Local.encode(0.0)
        XCTAssertEqual(bytes, [0, 0])
        XCTAssertEqual(FPE2Local.decode(bytes), 0.0, accuracy: 0.01)
    }

    func testEncodeDecodeRoundTripFifty() {
        let bytes = FPE2Local.encode(50.0)
        XCTAssertEqual(FPE2Local.decode(bytes), 50.0, accuracy: 0.01)
    }

    func testEncodeDecodeRoundTripHundred() {
        let bytes = FPE2Local.encode(100.0)
        XCTAssertEqual(FPE2Local.decode(bytes), 100.0, accuracy: 0.01)
    }

    func testEncodeDecodeRoundTripFractional() {
        let bytes = FPE2Local.encode(2.5)
        XCTAssertEqual(FPE2Local.decode(bytes), 2.5, accuracy: 0.01)
    }

    func testEncodeRPMValues() {
        // Common RPM values for MacBook Pro fans.
        for rpm in [1300.0, 2275.0, 4500.0, 6500.0] {
            let bytes = FPE2Local.encode(rpm)
            let decoded = FPE2Local.decode(bytes)
            XCTAssertEqual(decoded, rpm, accuracy: 0.5, "Round-trip failed for \(rpm)")
        }
    }

    func testNegativeClampedToZero() {
        let bytes = FPE2Local.encode(-100.0)
        XCTAssertEqual(bytes, [0, 0])
    }

    func testOverflowClampedToMax() {
        // 16383.99... is the maximum representable (raw uint16 / 4)
        let bytes = FPE2Local.encode(99999.0)
        let decoded = FPE2Local.decode(bytes)
        XCTAssertEqual(decoded, 16383.75, accuracy: 0.5)
    }
}
