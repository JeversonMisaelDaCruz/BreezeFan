import CoreGraphics

/// Border-radius tokens. Mirrors the JSX design system values from
/// `~/Downloads/FanControl/app/{main-mvp,window-shell,curve-editor}.jsx`.
public enum FCRadius {
    /// Small chips/buttons: helper-offline retry chip, value badges.
    /// JSX: implicit ~10pt for small interactive surfaces.
    public static let chip: CGFloat = 10

    /// Secondary cards (e.g. footer "Edit fan curve" trigger,
    /// inner sub-sections inside the curve editor sheet).
    /// JSX: `radius={14}` — see `main-mvp.jsx:75` (footer) and
    /// `curve-editor.jsx` inner section divs.
    public static let cardSmall: CGFloat = 14

    /// Primary cards inside the window content (hero CPU card,
    /// fans card, mode/preset card).
    /// JSX: `radius={18}` — see `main-mvp.jsx:23,48,56`.
    /// **Was 14 prior to fix-liquid-glass-fidelity** — the previous
    /// value caused the cards to look too tight vs the JSX mockup.
    public static let card: CGFloat = 18

    /// Curve editor modal sheet body.
    /// JSX: `radius={18}` — `curve-editor.jsx` outer container.
    public static let sheet: CGFloat = 18

    /// Window itself / outermost glass surface.
    /// JSX: `radius={22}` — `window-shell.jsx:107`.
    public static let window: CGFloat = 22
}
