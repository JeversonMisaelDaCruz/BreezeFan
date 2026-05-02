import Foundation

/// Linear interpolation between curve steps. Pure, no IO.
///
/// - Above the last point: clamps to the last duty.
/// - Below the first point: clamps to the first duty (NOT linear-down to 0).
/// - Between points: linear in (temp, duty).
public enum CurveInterpolator {
    public static func interpolate(temp: Double, curve: Curve) -> Double {
        let steps = curve.steps
        guard !steps.isEmpty else { return 0 }
        if steps.count == 1 { return Double(steps[0].duty) }

        if temp <= Double(steps.first!.temp) { return Double(steps.first!.duty) }
        if temp >= Double(steps.last!.temp)  { return Double(steps.last!.duty) }

        for i in 1..<steps.count {
            let lo = steps[i - 1]
            let hi = steps[i]
            if temp <= Double(hi.temp) {
                let t = (temp - Double(lo.temp)) / Double(hi.temp - lo.temp)
                return Double(lo.duty) + t * Double(hi.duty - lo.duty)
            }
        }
        return Double(steps.last!.duty)
    }

    /// Convenience: convert `duty %` (0-100) to a target RPM for a fan with given Mn/Mx.
    public static func dutyToRPM(duty: Double, mn: Int, mx: Int) -> Int {
        let clamped = min(max(duty, 0), 100)
        let rpm = Double(mn) + (clamped / 100.0) * Double(mx - mn)
        return Int(rpm.rounded())
    }
}
