import SwiftUI

/// Main window content. Liquid Glass cards on top of FCWallpaper.
///
/// Layout mirrors `~/Downloads/FanControl/app/main-mvp.jsx`:
///   root padding: `EdgeInsets(top: 4, leading: 14, bottom: 14, trailing: 14)`,
///   card spacing: 12pt,
///   no in-content title (window titlebar provides identity).
///
/// Cards (top → bottom):
///   1. Hero CPU — `radius=18 padding=18`, label "CPU", 64pt thin number, status dot+subtext
///   2. Fans     — `radius=18 padding="14 16"`, list of `GlassFanRow`
///   3. Mode     — `radius=18 padding="14 16"`, 2x2 grid of `PresetButton`
///   4. Footer   — `radius=14 padding="11 14"`, accent square + "Edit fan curve" + chevron
struct MainView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
    @State private var sensorVM = SensorViewModel()
    @State private var footerHovered = false

    var body: some View {
        // Body is rendered below the FCWindow titlebar zone (42pt). Padding here
        // is the JSX root padding `4px 14px 14px` (main-mvp.jsx:20), now relative
        // to the bottom of the titlebar — no more `.padding(.top, 28)` hack.
        VStack(spacing: 12) {
            if !sensorVM.helperReachable {
                helperOfflineBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            heroCard
            fansCard
            modeCard

            // Push the footer to the bottom of the available space.
            Spacer(minLength: 0)

            footerCard
        }
        .padding(EdgeInsets(top: 4, leading: 14, bottom: 14, trailing: 14))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(FCAnimation.normal, value: sensorVM.helperReachable)
        .onAppear {
            sensorVM.start()
            // Capture the scene's openWindow so AppKit menus can reopen the window
            // after it has been closed.
            WindowAccess.shared.openMainWindow = { openWindow(id: "main") }
        }
        .onDisappear { sensorVM.stop() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:     sensorVM.start(); Task { await sensorVM.pollOnce() }
            case .background, .inactive: sensorVM.stop()
            @unknown default: break
            }
        }
    }

    // MARK: - Helper offline banner (kept; not in JSX MVP but needed for UX)

    private var helperOfflineBanner: some View {
        HStack(spacing: FCSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(FCTheme.warn)
            VStack(alignment: .leading, spacing: 2) {
                Text("Helper offline")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FCTheme.textPrimary)
                Text(sensorVM.lastError ?? "Approve helper in System Settings.")
                    .font(.system(size: 9))
                    .foregroundStyle(FCTheme.textMuted)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                appState.reinstallHelper()
                Task { await sensorVM.pollOnce() }
            } label: {
                Text("Retry")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FCTheme.warn)
                    .padding(.horizontal, FCSpacing.sm)
                    .padding(.vertical, 3)
                    .background(FCTheme.warn.opacity(0.15))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, FCSpacing.md + 2)
        .padding(.vertical, FCSpacing.sm)
        .background(FCTheme.warn.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: FCRadius.chip, style: .continuous))
    }

    // MARK: - Card 1: Hero (CPU)
    //
    //   JSX `main-mvp.jsx:22-45` — radius 18, padding 18 (all sides),
    //   label "CPU" (10pt uppercase tracking 1.6), 64pt thin number with
    //   text-shadow + letterSpacing -3, "°C"/"°F" 22pt 0.6 opacity, status row
    //   with green/amber/red dot + subtext.

    private var heroCard: some View {
        FCGlassSurface(radius: FCRadius.card, intensity: 0.85, sheen: true) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CPU")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Color.white.opacity(0.55))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(appState.formatTemp(sensorVM.snapshot.cpuTemp))
                        .font(.system(size: 64, weight: .thin))
                        .tracking(-3)
                        .foregroundStyle(Color.white)
                        .fcTabularNums()
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.1), value: sensorVM.snapshot.cpuTemp)
                        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 2)
                    Text(appState.tempUnitSuffix())
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .lineLimit(1)

                statusRow
                    .padding(.top, 8 - 6) // VStack already has 6pt; bump to total 8pt
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Green/amber/red dot + dynamic subtext. Minimalist — no glow halo,
    /// just a flat colored dot.
    private var statusRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 6, height: 6)

            Text(statusMessage)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.7))
                .lineLimit(1)
        }
    }

    private var statusDotColor: Color {
        guard sensorVM.helperReachable else { return Color.white.opacity(0.30) }
        guard let t = sensorVM.snapshot.cpuTemp else { return Color(hex: "22c55e") }
        switch t {
        case ..<80: return Color(hex: "22c55e") // green
        case ..<95: return Color(hex: "f59e0b") // amber
        default:    return FCTheme.danger       // red
        }
    }

    private var statusMessage: String {
        guard sensorVM.helperReachable else { return "Helper offline" }
        let activeFans = activeFanCount
        let fanText = "\(activeFans) fan\(activeFans == 1 ? "" : "s") active"
        guard let t = sensorVM.snapshot.cpuTemp else {
            return "Sensors warming up · \(fanText)"
        }
        switch t {
        case ..<80: return "Running cool · \(fanText)"
        case ..<95: return "Warming up · \(fanText)"
        default:    return "Hot — boosting fans"
        }
    }

    private var activeFanCount: Int {
        let snap = sensorVM.snapshot
        var n = 0
        if (snap.leftRPM ?? 0) > 0 { n += 1 }
        if (snap.rightRPM ?? 0) > 0 { n += 1 }
        return n
    }

    // MARK: - Card 2: Fans
    //   JSX `main-mvp.jsx:47-53` — radius 18, padding "14 16", section
    //   label "Fans", VStack of GlassFanRow with gap 10.

    private var fansCard: some View {
        FCGlassSurface(radius: FCRadius.card, intensity: 0.85, sheen: true) {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("FANS")
                    .padding(.bottom, 0)

                FanRow(label: "Left Fan",
                       rpm: sensorVM.snapshot.leftRPM,
                       duty: sensorVM.snapshot.leftDuty,
                       maxRPM: appState.fanCeilings?.f0Mx ?? 6500)

                FanRow(label: "Right Fan",
                       rpm: sensorVM.snapshot.rightRPM,
                       duty: sensorVM.snapshot.rightDuty,
                       maxRPM: appState.fanCeilings?.f1Mx ?? 6500)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Card 3: Mode (presets)
    //   JSX `main-mvp.jsx:55-65` — radius 18, padding "14 16", section
    //   label "Mode", 2x2 grid with gap 6.

    private var modeCard: some View {
        FCGlassSurface(radius: FCRadius.card, intensity: 0.85, sheen: true) {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("MODE")
                PresetGrid()
                    .disabled(!sensorVM.helperReachable)
                    .opacity(sensorVM.helperReachable ? 1.0 : 0.4)
                CurveModeRow()
                    .disabled(!sensorVM.helperReachable)
                    .opacity(sensorVM.helperReachable ? 1.0 : 0.4)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Card 4: Footer (Edit fan curve)
    //   JSX `main-mvp.jsx:69-95` — glass card radius 14, padding "11 14",
    //   accent square (22pt, radius 6) with curve SVG inside, "Edit fan curve",
    //   chevron `›` on the right.

    private var footerCard: some View {
        Button {
            appState.curveEditorPresented = true
        } label: {
            FCGlassSurface(radius: FCRadius.cardSmall,
                           intensity: footerHovered ? 1.0 : 0.85,
                           sheen: true) {
                HStack(spacing: 0) {
                    HStack(spacing: 9) {
                        accentCurveSquare
                        Text("Edit fan curve")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.95))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .keyboardShortcut("e", modifiers: .command)
        .disabled(!sensorVM.helperReachable)
        .opacity(sensorVM.helperReachable ? 1.0 : 0.4)
        .onHover { hovering in
            footerHovered = hovering
            if sensorVM.helperReachable {
                if hovering { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            }
        }
        .animation(FCAnimation.fast, value: footerHovered)
    }

    /// 22×22 accent square with the curve SVG inside. Minimalist — no glow.
    private var accentCurveSquare: some View {
        let accent = appState.accentColor
        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(accent.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(accent.opacity(0.40), lineWidth: 0.5)
                )

            CurveGlyph()
                .stroke(accent,
                        style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))
                .frame(width: 13, height: 13)
        }
        .frame(width: 22, height: 22)
    }

    // MARK: - Section label helper

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(Color.white.opacity(0.55))
    }
}

/// Curve path used by the footer accent square. Mirrors JSX
/// `M3 18 C 7 18, 9 6, 13 6 S 17 18, 21 18` from `main-mvp.jsx:85`.
/// Drawn in a 24×24 viewBox, scaled to whatever frame() gives us.
private struct CurveGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width  / 24.0
        let sy = rect.height / 24.0
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var path = Path()
        path.move(to: p(3, 18))
        path.addCurve(to:    p(13, 6),
                      control1: p(7, 18),
                      control2: p(9,  6))
        // S 17 18, 21 18 — smooth cubic, control1 reflected from previous control2
        // previous control2 was (9,6); reflected through (13,6) → (17,6)
        path.addCurve(to:    p(21, 18),
                      control1: p(17, 6),
                      control2: p(17, 18))
        return path
    }
}
