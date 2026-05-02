import XCTest

/// Tests Task 14.1: Hysteresis state machine.
/// Mirrors `Helper/Control/Hysteresis.swift` for SPM compatibility.
final class HysteresisTests: XCTestCase {
    /// Local mirror of Hysteresis (no IO dependency).
    final class LocalHysteresis {
        private(set) var lastEffective: Double
        let dropThreshold: Double
        init(initialTemp: Double = 50.0, dropThreshold: Double = 3.0) {
            self.lastEffective = initialTemp
            self.dropThreshold = dropThreshold
        }
        @discardableResult
        func apply(_ current: Double) -> Double {
            if current >= lastEffective {
                lastEffective = current
            } else if current <= lastEffective - dropThreshold {
                lastEffective = current
            }
            return lastEffective
        }
    }

    func testUpAcceptedImmediately() {
        let h = LocalHysteresis(initialTemp: 50)
        XCTAssertEqual(h.apply(55), 55)
    }

    func testDownLessThanThresholdIgnored() {
        let h = LocalHysteresis(initialTemp: 60)
        XCTAssertEqual(h.apply(58), 60) // 2°C drop, ignored
    }

    func testDownAtExactlyThresholdAccepted() {
        let h = LocalHysteresis(initialTemp: 60)
        XCTAssertEqual(h.apply(57), 57) // 3°C drop, accepted (<=)
    }

    func testDownAboveThresholdAccepted() {
        let h = LocalHysteresis(initialTemp: 60)
        XCTAssertEqual(h.apply(50), 50)
    }

    func testOscillatingSequence() {
        let h = LocalHysteresis(initialTemp: 60)
        // Sequence: 60 -> 58 (ignored, stays 60) -> 62 (up, accepted) -> 58 (4 below, accepted) -> 62 (up, accepted)
        XCTAssertEqual(h.apply(58), 60)
        XCTAssertEqual(h.apply(62), 62)
        XCTAssertEqual(h.apply(58), 58)
        XCTAssertEqual(h.apply(62), 62)
    }

    func testEqualValueAccepted() {
        let h = LocalHysteresis(initialTemp: 60)
        XCTAssertEqual(h.apply(60), 60)
    }
}
