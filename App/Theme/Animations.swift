import SwiftUI

/// Animation tokens. Use these instead of literal `.easeOut(duration:)` calls.
public enum FCAnimation {
    /// Hover, micro-interactions (~150ms).
    public static let fast: Animation = .easeOut(duration: 0.15)

    /// Mode change, transition between states (~260ms). Mirrors JSX `cubic-bezier(.2,.8,.3,1)`.
    public static let normal: Animation = .easeOut(duration: 0.26)

    /// Banner slide-in / slide-out (~400ms).
    public static let slow: Animation = .easeOut(duration: 0.4)

    /// Spring for sheet open/close — bouncy but tight.
    public static let bouncy: Animation = .spring(response: 0.26, dampingFraction: 0.85)
}
