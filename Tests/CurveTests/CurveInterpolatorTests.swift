import XCTest
import FanControlShared

/// Tests Task 12.4: CurveInterpolator linear interpolation, clamps at extremes.
final class CurveInterpolatorTests: XCTestCase {
    let curve = Curve.default // (40,20) (60,50) (75,80) (90,100)

    func testInterpolateMiddleSegment() {
        // temp=50 between (40,20) and (60,50): 50 = 20 + (50-40)/(60-40) * (50-20) = 35
        let duty = CurveInterpolator.interpolate(temp: 50, curve: curve)
        XCTAssertEqual(duty, 35.0, accuracy: 0.01)
    }

    func testInterpolateBetween60And75() {
        // temp=70: 70-60/15 * (80-50) + 50 = 0.667*30 + 50 = 70
        let duty = CurveInterpolator.interpolate(temp: 70, curve: curve)
        XCTAssertEqual(duty, 70.0, accuracy: 0.01)
    }

    func testClampAboveLastPoint() {
        let duty = CurveInterpolator.interpolate(temp: 95, curve: curve)
        XCTAssertEqual(duty, 100.0)
    }

    func testClampBelowFirstPoint() {
        // Below 40°C should clamp to 20% (NOT extrapolate down to 0%)
        let duty = CurveInterpolator.interpolate(temp: 25, curve: curve)
        XCTAssertEqual(duty, 20.0)
    }

    func testExactMatchOnPoint() {
        XCTAssertEqual(CurveInterpolator.interpolate(temp: 60, curve: curve), 50.0)
        XCTAssertEqual(CurveInterpolator.interpolate(temp: 90, curve: curve), 100.0)
    }

    func testDutyToRPM() {
        // 35% with mn=1300 mx=6500: 1300 + 0.35 * 5200 = 3120
        let rpm = CurveInterpolator.dutyToRPM(duty: 35, mn: 1300, mx: 6500)
        XCTAssertEqual(rpm, 3120)
    }

    func testDutyToRPMClampedHigh() {
        let rpm = CurveInterpolator.dutyToRPM(duty: 200, mn: 1300, mx: 6500)
        XCTAssertEqual(rpm, 6500)
    }

    func testDutyToRPMClampedLow() {
        let rpm = CurveInterpolator.dutyToRPM(duty: -50, mn: 1300, mx: 6500)
        XCTAssertEqual(rpm, 1300)
    }
}
