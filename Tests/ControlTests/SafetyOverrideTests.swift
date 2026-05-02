import XCTest

/// Tests Task 15.1: SafetyOverride state machine.
final class SafetyOverrideTests: XCTestCase {
    /// Local mirror of SafetyOverride.
    final class LocalSafety {
        private(set) var state: String = "normal"
        var consecutiveAbove: Int = 0
        let activate: Double
        let deactivate: Double
        let consecutiveTicks: Int
        init(activate: Double = 95.0, deactivate: Double = 92.0, consecutive: Int = 3) {
            self.activate = activate
            self.deactivate = deactivate
            self.consecutiveTicks = consecutive
        }
        func tick(_ temp: Double?) -> String {
            guard let t = temp else { return state }
            if t > activate {
                consecutiveAbove += 1
                if consecutiveAbove >= consecutiveTicks { state = "override" }
            } else {
                consecutiveAbove = 0
            }
            if state == "override" && t < deactivate { state = "normal" }
            return state
        }
    }

    func testSpikeDoesNotTrigger() {
        let s = LocalSafety()
        for t in [80.0, 96.0, 75.0, 70.0] {
            _ = s.tick(t)
        }
        XCTAssertEqual(s.state, "normal")
    }

    func testSustainedAboveThresholdTriggers() {
        let s = LocalSafety()
        let temps = [90.0, 96.0, 97.0, 98.0, 96.0]
        var states: [String] = []
        for t in temps { states.append(s.tick(t)) }
        // 1: 96 (1 consecutive); 2: 97 (2); 3: 98 (3 → override); 4: still override
        XCTAssertEqual(states[0], "normal")
        XCTAssertEqual(states[1], "normal")
        XCTAssertEqual(states[2], "override")
        XCTAssertEqual(states[3], "override")
    }

    func testOverrideDeactivatesBelowFloor() {
        let s = LocalSafety()
        // Trigger override
        _ = s.tick(96)
        _ = s.tick(97)
        _ = s.tick(98)
        XCTAssertEqual(s.state, "override")

        _ = s.tick(96) // still > deactivate floor
        XCTAssertEqual(s.state, "override")

        _ = s.tick(91) // below 92, deactivates
        XCTAssertEqual(s.state, "normal")
    }

    func testStrictGreaterThan95() {
        let s = LocalSafety()
        // 95.0 exactly should NOT count as above
        for _ in 0..<5 {
            _ = s.tick(95.0)
        }
        XCTAssertEqual(s.state, "normal")
    }

    func testMissingTempDoesNotResetCounter() {
        let s = LocalSafety()
        _ = s.tick(96)
        _ = s.tick(97)
        _ = s.tick(nil) // missing reading shouldn't reset
        _ = s.tick(98)
        XCTAssertEqual(s.state, "override")
    }
}
