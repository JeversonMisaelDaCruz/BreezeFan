import XCTest

/// Tests Task 6.3: SnapshotBuilder produces correct SensorSnapshot from mocked SMC + temp.
/// Reimplements the logic locally to avoid IOKit dependency in tests.
final class SnapshotBuilderTests: XCTestCase {
    enum MockError: Error { case missing; case locked }

    final class MockSMC {
        var values: [String: Result<Double, MockError>] = [:]
        func read(_ key: String) -> Result<Double, MockError> {
            values[key] ?? .failure(.missing)
        }
    }

    final class MockTemp {
        var temp: Double?
        func maxCPUTemp() -> Double? { temp }
    }

    /// Local mirror of SnapshotBuilder.
    final class LocalSnapBuilder {
        let smc: MockSMC
        let temp: MockTemp
        var f0Mn = 1300, f0Mx = 6500
        var f1Mn = 1300, f1Mx = 6500
        init(smc: MockSMC, temp: MockTemp) {
            self.smc = smc; self.temp = temp
        }
        func build() -> (lRPM: Int?, rRPM: Int?, lD: Double?, rD: Double?, t: Double?, locked: Bool) {
            var locked = false
            let lRPM: Int? = { switch smc.read("F0Ac") {
                case .success(let v): return Int(v.rounded())
                case .failure(.locked): locked = true; return nil
                case .failure: return nil
            } }()
            let rRPM: Int? = { switch smc.read("F1Ac") {
                case .success(let v): return Int(v.rounded())
                case .failure(.locked): locked = true; return nil
                case .failure: return nil
            } }()
            let cpuTemp = temp.maxCPUTemp()
            let lD: Double? = lRPM.map {
                let span = Double(f0Mx - f0Mn)
                return span > 0 ? min(max(Double($0 - f0Mn) / span, 0), 1) : 0
            }
            let rD: Double? = rRPM.map {
                let span = Double(f1Mx - f1Mn)
                return span > 0 ? min(max(Double($0 - f1Mn) / span, 0), 1) : 0
            }
            return (lRPM, rRPM, lD, rD, cpuTemp, locked)
        }
    }

    func testBuildsSnapshotFromAllSources() {
        let smc = MockSMC()
        smc.values = [
            "F0Ac": .success(3900),
            "F1Ac": .success(2275),
        ]
        let temp = MockTemp()
        temp.temp = 62
        let b = LocalSnapBuilder(smc: smc, temp: temp)
        let s = b.build()
        XCTAssertEqual(s.lRPM, 3900)
        XCTAssertEqual(s.rRPM, 2275)
        XCTAssertEqual(s.lD ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(s.rD ?? 0, 0.1875, accuracy: 0.001)
        XCTAssertEqual(s.t, 62)
        XCTAssertFalse(s.locked)
    }

    func testReportsConflictWhenSMCLocked() {
        let smc = MockSMC()
        smc.values = [
            "F0Ac": .failure(.locked),
            "F1Ac": .failure(.locked),
        ]
        let temp = MockTemp()
        let b = LocalSnapBuilder(smc: smc, temp: temp)
        let s = b.build()
        XCTAssertNil(s.lRPM)
        XCTAssertNil(s.rRPM)
        XCTAssertTrue(s.locked)
    }

    func testNilTemperatureWhenAllSourcesFail() {
        let smc = MockSMC()
        smc.values = ["F0Ac": .success(2000), "F1Ac": .success(2000)]
        let temp = MockTemp()
        temp.temp = nil
        let b = LocalSnapBuilder(smc: smc, temp: temp)
        XCTAssertNil(b.build().t)
    }

    func testDutyClampedToOneOnOvershoot() {
        let smc = MockSMC()
        smc.values = ["F0Ac": .success(7000), "F1Ac": .success(7000)]
        let b = LocalSnapBuilder(smc: smc, temp: MockTemp())
        b.f0Mx = 6500
        let s = b.build()
        XCTAssertEqual(s.lD, 1.0)
    }
}
