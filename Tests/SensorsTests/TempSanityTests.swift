import XCTest

/// Tests for BUG 1 — temperature sanity range.
/// Mirrors the logic in `Helper/Sensors/TemperatureReader.swift` locally to test
/// without IOKit dependency.
final class TempSanityTests: XCTestCase {
    enum MockError: Error { case missing }

    final class MockSMC {
        var values: [String: Result<Double, MockError>] = [:]
        func read(_ key: String) -> Result<Double, MockError> {
            values[key] ?? .failure(.missing)
        }
    }

    final class MockIOHID {
        var temp: Double?
        func maxCPUTemperature() -> Double? { temp }
    }

    /// Local mirror of the TemperatureReader logic with sanity range.
    final class LocalTempReader {
        static let plausibleRange: ClosedRange<Double> = -20.0...120.0
        let smc: MockSMC
        let ioHID: MockIOHID
        init(smc: MockSMC, ioHID: MockIOHID) {
            self.smc = smc
            self.ioHID = ioHID
        }
        func maxCPUTemp() -> Double? {
            let keys = ["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H"]
            var values: [Double] = []
            for k in keys {
                if case .success(let v) = smc.read(k) {
                    if Self.plausibleRange.contains(v) {
                        values.append(v)
                    }
                }
            }
            if let m = values.max() { return m }
            if let temp = ioHID.maxCPUTemperature(), Self.plausibleRange.contains(temp) {
                return temp
            }
            return nil
        }
    }

    func testRejects200CelsiusAsAbsurd() {
        let smc = MockSMC()
        smc.values = ["Tp01": .success(200)]
        let r = LocalTempReader(smc: smc, ioHID: MockIOHID())
        XCTAssertNil(r.maxCPUTemp())
    }

    func testRejectsNegative50AsAbsurd() {
        let smc = MockSMC()
        smc.values = ["Tp05": .success(-50)]
        let r = LocalTempReader(smc: smc, ioHID: MockIOHID())
        XCTAssertNil(r.maxCPUTemp())
    }

    func testAcceptsTypicalIdleTemp() {
        let smc = MockSMC()
        smc.values = ["Tp01": .success(45)]
        let r = LocalTempReader(smc: smc, ioHID: MockIOHID())
        XCTAssertEqual(r.maxCPUTemp(), 45)
    }

    func testAccepts108CelsiusNearTjmax() {
        let smc = MockSMC()
        smc.values = ["Tp09": .success(108)]
        let r = LocalTempReader(smc: smc, ioHID: MockIOHID())
        XCTAssertEqual(r.maxCPUTemp(), 108)
    }

    func testRejectsAtUpperBoundary120Plus() {
        let smc = MockSMC()
        smc.values = [
            "Tp01": .success(120.5),    // out
            "Tp05": .success(45),       // valid
        ]
        let r = LocalTempReader(smc: smc, ioHID: MockIOHID())
        XCTAssertEqual(r.maxCPUTemp(), 45)
    }

    func testMixedValidAndAbsurdPicksMaxOfValid() {
        let smc = MockSMC()
        smc.values = [
            "Tp01": .success(1500),  // absurd
            "Tp05": .success(58),
            "Tp09": .success(62),
            "Tp0D": .success(-300),  // absurd
        ]
        let r = LocalTempReader(smc: smc, ioHID: MockIOHID())
        XCTAssertEqual(r.maxCPUTemp(), 62)
    }

    func testFallsBackToIOHIDOnlyWhenAllSMCAreInvalidOrError() {
        let smc = MockSMC()
        smc.values = [
            "Tp01": .success(-999),
            "Tp05": .success(999),
        ]
        let hid = MockIOHID()
        hid.temp = 60
        let r = LocalTempReader(smc: smc, ioHID: hid)
        XCTAssertEqual(r.maxCPUTemp(), 60)
    }

    func testIOHIDValueAlsoFilteredByRange() {
        let smc = MockSMC()
        let hid = MockIOHID()
        hid.temp = 500  // absurd
        let r = LocalTempReader(smc: smc, ioHID: hid)
        XCTAssertNil(r.maxCPUTemp())
    }

    func testZeroIsConsideredValid() {
        // Possibly 0°C readings exist on cold-boot — accept them.
        let smc = MockSMC()
        smc.values = ["Tp01": .success(0)]
        let r = LocalTempReader(smc: smc, ioHID: MockIOHID())
        XCTAssertEqual(r.maxCPUTemp(), 0)
    }
}
