import XCTest
import FanControlShared

/// Tests Task 9.2: Preset.targetMode() maps to expected ControlMode.
final class PresetTests: XCTestCase {
    func testSilentMaps35Percent() {
        if case .forced(let rpm) = Preset.silent.targetMode(f0Mx: 6500, f1Mx: 6500) {
            XCTAssertEqual(rpm, 2275) // 35% of 6500
        } else {
            XCTFail("Silent should be forced")
        }
    }

    func testBalancedMapsToAuto() {
        XCTAssertEqual(Preset.balanced.targetMode(f0Mx: 6500, f1Mx: 6500), .auto)
    }

    func testPerformanceMaps70Percent() {
        if case .forced(let rpm) = Preset.performance.targetMode(f0Mx: 6500, f1Mx: 6500) {
            XCTAssertEqual(rpm, 4550) // 70% of 6500
        } else {
            XCTFail("Performance should be forced")
        }
    }

    func testMaxMapsToMaxRPM() {
        if case .forced(let rpm) = Preset.max.targetMode(f0Mx: 6500, f1Mx: 6500) {
            XCTAssertEqual(rpm, 6500)
        } else {
            XCTFail("Max should be forced")
        }
    }

    func testAllCases() {
        XCTAssertEqual(Preset.allCases.count, 4)
    }

    func testRoundTripCodable() throws {
        for preset in Preset.allCases {
            let data = try JSONEncoder().encode(preset)
            let decoded = try JSONDecoder().decode(Preset.self, from: data)
            XCTAssertEqual(preset, decoded)
        }
    }
}
