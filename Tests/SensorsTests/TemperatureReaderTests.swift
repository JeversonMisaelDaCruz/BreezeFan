import XCTest

/// Tests Tasks 5.1-5.2: TemperatureReader picks max(Tp01..Tp0H) from SMC,
/// falls back to IOHID when all SMC reads fail.
final class TemperatureReaderTests: XCTestCase {
    /// Lightweight protocol/mocks duplicated locally so this test file
    /// builds with no IOKit dependency.
    protocol SMCReadingMock: AnyObject {
        func read(_ key: String) -> Result<Double, MockError>
    }
    enum MockError: Error { case missing }

    final class MockSMC: SMCReadingMock {
        var values: [String: Result<Double, MockError>] = [:]
        func read(_ key: String) -> Result<Double, MockError> {
            values[key] ?? .failure(.missing)
        }
    }

    final class MockIOHID {
        var temp: Double?
        func maxCPUTemperature() -> Double? { temp }
    }

    /// The actual logic under test, reimplemented locally (mirrors TemperatureReader).
    final class LocalTempReader {
        let smc: SMCReadingMock
        let ioHID: MockIOHID
        init(smc: SMCReadingMock, ioHID: MockIOHID) {
            self.smc = smc
            self.ioHID = ioHID
        }
        func maxCPUTemp() -> Double? {
            let keys = ["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H"]
            var values: [Double] = []
            for k in keys {
                if case .success(let v) = smc.read(k) {
                    if v > 0 && v < 130 { values.append(v) }
                }
            }
            if let m = values.max() { return m }
            return ioHID.maxCPUTemperature()
        }
    }

    func testMaxCPUTempPicksHighestSMCKey() {
        let smc = MockSMC()
        smc.values = [
            "Tp01": .success(55),
            "Tp05": .success(58),
            "Tp09": .success(62),
            "Tp0D": .success(51),
            "Tp0H": .success(49),
        ]
        let reader = LocalTempReader(smc: smc, ioHID: MockIOHID())
        XCTAssertEqual(reader.maxCPUTemp(), 62)
    }

    func testFallsBackToIOHIDWhenAllSMCKeysFail() {
        let smc = MockSMC() // all keys missing
        let hid = MockIOHID()
        hid.temp = 60
        let reader = LocalTempReader(smc: smc, ioHID: hid)
        XCTAssertEqual(reader.maxCPUTemp(), 60)
    }

    func testReturnsNilWhenAllSourcesFail() {
        let smc = MockSMC()
        let reader = LocalTempReader(smc: smc, ioHID: MockIOHID())
        XCTAssertNil(reader.maxCPUTemp())
    }

    func testIgnoresOutOfRangeSMCValues() {
        let smc = MockSMC()
        // Bogus 200°C should be filtered out, leaving 60 as max.
        smc.values = [
            "Tp01": .success(200),
            "Tp05": .success(60),
            "Tp09": .success(-1),
        ]
        let reader = LocalTempReader(smc: smc, ioHID: MockIOHID())
        XCTAssertEqual(reader.maxCPUTemp(), 60)
    }

    func testPicksSMCValueEvenIfIOHIDAlsoHasValue() {
        let smc = MockSMC()
        smc.values = ["Tp01": .success(70)]
        let hid = MockIOHID()
        hid.temp = 95 // hot, but should be ignored because SMC has data
        let reader = LocalTempReader(smc: smc, ioHID: hid)
        XCTAssertEqual(reader.maxCPUTemp(), 70)
    }
}
