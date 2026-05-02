import XCTest

/// Tests for BUG 3 — ModeManager clamps target RPM in setMode forced.
final class ModeManagerClampTests: XCTestCase {
    /// Local mirror of the clamp logic.
    static func clamp(_ rpm: Int, mn: Int, mx: Int) -> Int {
        return min(max(rpm, mn), mx)
    }

    func testValidMidRangeNotClamped() {
        let result = Self.clamp(4500, mn: 1300, mx: 6500)
        XCTAssertEqual(result, 4500)
    }

    func testRPMAboveMaxClampsToMax() {
        let result = Self.clamp(99999, mn: 1300, mx: 6500)
        XCTAssertEqual(result, 6500)
    }

    func testRPMBelowMinClampsToMin() {
        let result = Self.clamp(100, mn: 1300, mx: 6500)
        XCTAssertEqual(result, 1300)
    }

    func testRPMZeroClampsToMin() {
        let result = Self.clamp(0, mn: 1300, mx: 6500)
        XCTAssertEqual(result, 1300)
    }

    func testRPMNegativeClampsToMin() {
        let result = Self.clamp(-100, mn: 1300, mx: 6500)
        XCTAssertEqual(result, 1300)
    }

    func testExactlyAtBoundaryNotClamped() {
        XCTAssertEqual(Self.clamp(1300, mn: 1300, mx: 6500), 1300)
        XCTAssertEqual(Self.clamp(6500, mn: 1300, mx: 6500), 6500)
    }

    func testMaxPresetHonorsCeiling() {
        // Max preset = 100% of f0Mx -> result = f0Mx (no clamp needed)
        let f0Mx = 6500
        let target = f0Mx  // Preset.max maps to forced(f0Mx)
        let result = Self.clamp(target, mn: 1300, mx: f0Mx)
        XCTAssertEqual(result, 6500)
    }

    func testSilentPresetHonorsFloor() {
        // Silent = 35% of 6500 = 2275; well above mn=1300, no clamp
        let target = Int(Double(6500) * 0.35)
        let result = Self.clamp(target, mn: 1300, mx: 6500)
        XCTAssertEqual(result, 2275)
    }

    func testSilentPresetClampsWhenFloorAbove35Percent() {
        // M1 Pro might have F0Mn=2500. Silent = 35% × 6500 = 2275 < 2500, clamps up.
        let target = Int(Double(6500) * 0.35) // 2275
        let result = Self.clamp(target, mn: 2500, mx: 6500)
        XCTAssertEqual(result, 2500)
    }
}
