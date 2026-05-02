import SwiftUI

/// Canvas-rendered curve graph. Replicates `CurveGraph` from `curve-mvp.jsx`.
/// 320×140 viewBox, gridlines, danger zone, area gradient, hoverable points.
struct CurveGraph: View {
    let curve: Curve
    @Environment(AppState.self) private var appState
    @State private var hoverIndex: Int?

    private let viewBox = CGSize(width: 320, height: 140)
    private let pad = (l: 28.0, r: 8.0, t: 8.0, b: 22.0)

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / viewBox.width, geo.size.height / viewBox.height)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    let trans = CGAffineTransform(scaleX: scale, y: scale)
                    ctx.transform = trans

                    drawGridlines(ctx: ctx)
                    drawDangerZone(ctx: ctx)
                    drawAreaGradient(ctx: ctx)
                    drawCurveLine(ctx: ctx)
                    drawAxisLabels(ctx: ctx)
                }
                drawPoints(scale: scale)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(Color.black.opacity(0.18))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Geometry helpers

    private func xFor(_ temp: Double) -> CGFloat {
        let plotW = viewBox.width - pad.l - pad.r
        let normalized = (temp - 20.0) / (105.0 - 20.0)
        return CGFloat(pad.l) + plotW * CGFloat(min(max(normalized, 0), 1))
    }

    private func yFor(_ duty: Double) -> CGFloat {
        let plotH = viewBox.height - pad.t - pad.b
        let normalized = duty / 100.0
        return CGFloat(pad.t) + plotH * CGFloat(1 - min(max(normalized, 0), 1))
    }

    // MARK: - Drawing

    private func drawGridlines(ctx: GraphicsContext) {
        let gridColor = Color.white.opacity(0.05)
        let style = StrokeStyle(lineWidth: 0.5, dash: [2, 3])

        // Y gridlines: 0, 25, 50, 75, 100
        for d in [0.0, 25, 50, 75, 100] {
            let y = yFor(d)
            var path = Path()
            path.move(to: CGPoint(x: pad.l, y: y))
            path.addLine(to: CGPoint(x: viewBox.width - pad.r, y: y))
            ctx.stroke(path, with: .color(gridColor), style: style)
        }
        // X gridlines: 30, 50, 70, 90
        for t in [30.0, 50, 70, 90] {
            let x = xFor(t)
            var path = Path()
            path.move(to: CGPoint(x: x, y: pad.t))
            path.addLine(to: CGPoint(x: x, y: viewBox.height - pad.b))
            ctx.stroke(path, with: .color(gridColor), style: style)
        }
    }

    private func drawDangerZone(ctx: GraphicsContext) {
        let x0 = xFor(85)
        let rect = CGRect(
            x: x0, y: pad.t,
            width: viewBox.width - pad.r - x0,
            height: viewBox.height - pad.t - pad.b
        )
        ctx.fill(Path(rect), with: .color(Color(hex: "#ef4444").opacity(0.06)))
    }

    private func drawCurveLine(ctx: GraphicsContext) {
        guard curve.steps.count >= 2 else { return }
        var path = Path()
        path.move(to: CGPoint(x: xFor(Double(curve.steps[0].temp)),
                              y: yFor(Double(curve.steps[0].duty))))
        for step in curve.steps.dropFirst() {
            path.addLine(to: CGPoint(x: xFor(Double(step.temp)),
                                     y: yFor(Double(step.duty))))
        }
        ctx.stroke(path, with: .color(appState.accentColor), lineWidth: 1.8)
    }

    private func drawAreaGradient(ctx: GraphicsContext) {
        guard curve.steps.count >= 2 else { return }
        var path = Path()
        path.move(to: CGPoint(x: xFor(Double(curve.steps[0].temp)),
                              y: viewBox.height - pad.b))
        for step in curve.steps {
            path.addLine(to: CGPoint(x: xFor(Double(step.temp)),
                                     y: yFor(Double(step.duty))))
        }
        path.addLine(to: CGPoint(x: xFor(Double(curve.steps.last!.temp)),
                                 y: viewBox.height - pad.b))
        path.closeSubpath()

        let gradient = Gradient(colors: [
            appState.accentColor.opacity(0.35),
            appState.accentColor.opacity(0.0),
        ])
        ctx.fill(
            path,
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: 0, y: pad.t),
                endPoint: CGPoint(x: 0, y: viewBox.height - pad.b)
            )
        )
    }

    private func drawAxisLabels(ctx: GraphicsContext) {
        let labelColor = Color.white.opacity(0.35)
        let font = Font.system(size: 8, weight: .regular, design: .monospaced)

        // Y labels: 0, 25, 50, 75, 100
        for d in [0.0, 25, 50, 75, 100] {
            let y = yFor(d)
            let text = Text("\(Int(d))").font(font).foregroundColor(labelColor)
            ctx.draw(text, at: CGPoint(x: 4, y: y))
        }
        // X labels: 30°, 50°, 70°, 90°
        for t in [30.0, 50, 70, 90] {
            let x = xFor(t)
            let text = Text("\(Int(t))°").font(font).foregroundColor(labelColor)
            ctx.draw(text, at: CGPoint(x: x, y: viewBox.height - 8))
        }
    }

    @ViewBuilder
    private func drawPoints(scale: CGFloat) -> some View {
        ForEach(Array(curve.steps.enumerated()), id: \.offset) { idx, step in
            let x = xFor(Double(step.temp)) * scale
            let y = yFor(Double(step.duty)) * scale
            let radius: CGFloat = hoverIndex == idx ? 4 : 3
            ZStack {
                Circle()
                    .fill(FCTheme.bgGraphiteBottom)
                    .frame(width: radius * 2, height: radius * 2)
                    .overlay(
                        Circle()
                            .strokeBorder(appState.accentColor, lineWidth: 1.5)
                    )
                if hoverIndex == idx {
                    Text("\(step.temp)° / \(step.duty)%")
                        .font(FCFont.badge)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(appState.accentColor)
                        .cornerRadius(3)
                        .offset(y: -16)
                }
            }
            .position(x: x, y: y)
            .onHover { hovering in
                hoverIndex = hovering ? idx : (hoverIndex == idx ? nil : hoverIndex)
            }
        }
    }
}
