import XCTest
import FanControlShared

/// Tests for BUG 3 — fan ceilings validity range.
final class FanCeilingsValidityTests: XCTestCase {
    func testValidCeilings() {
        XCTAssertTrue(FanCeilings.validate(f0Mn: 1300, f0Mx: 6500, f1Mn: 1300, f1Mx: 6500))
    }

    func testValidWithDifferentFans() {
        XCTAssertTrue(FanCeilings.validate(f0Mn: 1500, f0Mx: 5800, f1Mn: 1400, f1Mx: 6200))
    }

    func testInvalidF0MxTooLow() {
        // 38 RPM as F0Mx is the actual bug we hit
        XCTAssertFalse(FanCeilings.validate(f0Mn: 1300, f0Mx: 38, f1Mn: 1300, f1Mx: 6500))
    }

    func testInvalidF0MnTooHigh() {
        // 5000 RPM as F0Mn is implausible
        XCTAssertFalse(FanCeilings.validate(f0Mn: 5000, f0Mx: 6500, f1Mn: 1300, f1Mx: 6500))
    }

    func testInvalidF0MxTooHigh() {
        // 50000 RPM is way out of range
        XCTAssertFalse(FanCeilings.validate(f0Mn: 1300, f0Mx: 50000, f1Mn: 1300, f1Mx: 6500))
    }

    func testInvalidF1MxLowerThanF1Mn() {
        // Inverted ceilings are invalid
        XCTAssertFalse(FanCeilings.validate(f0Mn: 1300, f0Mx: 6500, f1Mn: 5000, f1Mx: 4000))
    }

    func testValidAtBoundaryLow() {
        XCTAssertTrue(FanCeilings.validate(f0Mn: 500, f0Mx: 3500, f1Mn: 500, f1Mx: 3500))
    }

    func testValidAtBoundaryHigh() {
        XCTAssertTrue(FanCeilings.validate(f0Mn: 3000, f0Mx: 10000, f1Mn: 3000, f1Mx: 10000))
    }

    func testInvalidJustBelowMnRange() {
        XCTAssertFalse(FanCeilings.validate(f0Mn: 499, f0Mx: 6500, f1Mn: 1300, f1Mx: 6500))
    }

    func testInvalidJustAboveMxRange() {
        XCTAssertFalse(FanCeilings.validate(f0Mn: 1300, f0Mx: 10001, f1Mn: 1300, f1Mx: 6500))
    }

    func testDefaultsAreInvalid() {
        // Defaults are valid in the range but `valid: false` flag is set deliberately.
        XCTAssertFalse(FanCeilings.defaults.valid)
        // The numeric values themselves are within range though
        XCTAssertTrue(FanCeilings.validate(
            f0Mn: FanCeilings.defaults.f0Mn,
            f0Mx: FanCeilings.defaults.f0Mx,
            f1Mn: FanCeilings.defaults.f1Mn,
            f1Mx: FanCeilings.defaults.f1Mx
        ))
    }

    func testCodableRoundTrip() throws {
        let original = FanCeilings(f0Mn: 1300, f0Mx: 6500, f1Mn: 1300, f1Mx: 6500, valid: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FanCeilings.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
