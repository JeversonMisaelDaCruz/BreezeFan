import Foundation

/// Pure validator for a `Curve`. No IO, easy to unit-test.
public enum CurveValidator {
    public static func validate(_ curve: Curve) -> Result<Void, CurveError> {
        let steps = curve.steps

        if steps.count < 2 { return .failure(.tooFewSteps) }
        if steps.count > 6 { return .failure(.tooManySteps) }

        for step in steps {
            if step.temp < 20 || step.temp > 105 {
                return .failure(.invalidTempRange(temp: step.temp))
            }
            if step.duty < 0 || step.duty > 100 {
                return .failure(.invalidDutyRange(duty: step.duty))
            }
        }

        // Ascending order, no duplicates
        for i in 1..<steps.count {
            if steps[i].temp <= steps[i - 1].temp {
                if steps[i].temp == steps[i - 1].temp {
                    return .failure(.duplicateTemp)
                }
                return .failure(.unordered)
            }
        }

        return .success(())
    }
}
