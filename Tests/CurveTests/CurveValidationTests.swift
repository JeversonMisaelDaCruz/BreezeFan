import XCTest
import FanControlShared

/// Tests Task 10.2: CurveValidator covers all error variants.
final class CurveValidationTests: XCTestCase {
    func testDefaultIsValid() {
        if case .failure(let err) = CurveValidator.validate(.default) {
            XCTFail("default should be valid; got \(err)")
        }
    }

    func testTooFewSteps() {
        let curve = Curve(steps: [CurveStep(temp: 60, duty: 50)])
        XCTAssertEqual(CurveValidator.validate(curve), .failure(.tooFewSteps))
    }

    func testTooManySteps() {
        let curve = Curve(steps: (0..<7).map { CurveStep(temp: 30 + $0 * 5, duty: $0 * 10) })
        XCTAssertEqual(CurveValidator.validate(curve), .failure(.tooManySteps))
    }

    func testUnordered() {
        let curve = Curve(steps: [
            CurveStep(temp: 40, duty: 20),
            CurveStep(temp: 30, duty: 40),
            CurveStep(temp: 80, duty: 60),
        ])
        XCTAssertEqual(CurveValidator.validate(curve), .failure(.unordered))
    }

    func testDuplicateTemp() {
        let curve = Curve(steps: [
            CurveStep(temp: 40, duty: 20),
            CurveStep(temp: 40, duty: 50),
        ])
        XCTAssertEqual(CurveValidator.validate(curve), .failure(.duplicateTemp))
    }

    func testTempOutOfRangeLow() {
        let curve = Curve(steps: [
            CurveStep(temp: 19, duty: 20),
            CurveStep(temp: 60, duty: 50),
        ])
        XCTAssertEqual(CurveValidator.validate(curve), .failure(.invalidTempRange(temp: 19)))
    }

    func testTempOutOfRangeHigh() {
        let curve = Curve(steps: [
            CurveStep(temp: 40, duty: 20),
            CurveStep(temp: 110, duty: 100),
        ])
        XCTAssertEqual(CurveValidator.validate(curve), .failure(.invalidTempRange(temp: 110)))
    }

    func testDutyOutOfRangeLow() {
        let curve = Curve(steps: [
            CurveStep(temp: 40, duty: -1),
            CurveStep(temp: 60, duty: 50),
        ])
        XCTAssertEqual(CurveValidator.validate(curve), .failure(.invalidDutyRange(duty: -1)))
    }

    func testDutyOutOfRangeHigh() {
        let curve = Curve(steps: [
            CurveStep(temp: 40, duty: 20),
            CurveStep(temp: 60, duty: 101),
        ])
        XCTAssertEqual(CurveValidator.validate(curve), .failure(.invalidDutyRange(duty: 101)))
    }

    func testValidWithSixSteps() {
        let curve = Curve(steps: [
            CurveStep(temp: 30, duty: 10),
            CurveStep(temp: 45, duty: 30),
            CurveStep(temp: 60, duty: 50),
            CurveStep(temp: 75, duty: 70),
            CurveStep(temp: 90, duty: 90),
            CurveStep(temp: 100, duty: 100),
        ])
        if case .failure(let err) = CurveValidator.validate(curve) {
            XCTFail("6-step valid curve rejected: \(err)")
        }
    }
}
