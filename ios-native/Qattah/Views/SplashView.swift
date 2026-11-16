import SwiftUI

/// The Qattah mark (same design as the website logo): a receipt with three
/// lines and a check badge, drawn with shapes so it can be animated.
struct QattahLogoMark: View {
    /// 0…1 — how much of the receipt outline and lines are drawn.
    var drawProgress: CGFloat = 1
    /// 0…1 — scale/opacity of the check badge.
    var badgeProgress: CGFloat = 1
    var size: CGFloat = 120

    private let mint = Color(red: 0.43, green: 0.91, blue: 0.72)   // #6EE7B7
    private let emerald = Color(red: 0.06, green: 0.73, blue: 0.51) // #10B981

    var body: some View {
        let unit = size / 120
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.02, green: 0.31, blue: 0.21),
                                              Color(red: 0.02, green: 0.37, blue: 0.27)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 108 * unit, height: 108 * unit)

            // Receipt
            RoundedRectangle(cornerRadius: 8 * unit)
                .fill(emerald.opacity(0.15 * drawProgress))
                .frame(width: 52 * unit, height: 64 * unit)
            RoundedRectangle(cornerRadius: 8 * unit)
                .trim(from: 0, to: drawProgress)
                .stroke(LinearGradient(colors: [Color(red: 0.2, green: 0.83, blue: 0.6), emerald],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 2 * unit, lineCap: .round))
                .frame(width: 52 * unit, height: 64 * unit)

            // Lines (drawn one after another, right-to-left like Arabic text)
            VStack(alignment: .trailing, spacing: 9.5 * unit) {
                line(width: 32, opacity: 1, start: 0.25, unit: unit)
                line(width: 32, opacity: 0.6, start: 0.45, unit: unit)
                line(width: 18, opacity: 0.4, start: 0.65, unit: unit)
            }
            .frame(width: 32 * unit, alignment: .trailing)
            .offset(y: -2 * unit)

            // Check badge
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [emerald, Color(red: 0.02, green: 0.59, blue: 0.41)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                CheckShape()
                    .trim(from: 0, to: badgeProgress)
                    .stroke(.white, style: StrokeStyle(lineWidth: 2.5 * unit, lineCap: .round, lineJoin: .round))
                    .padding(8 * unit)
            }
            .frame(width: 28 * unit, height: 28 * unit)
            .scaleEffect(0.3 + 0.7 * badgeProgress)
            .opacity(badgeProgress)
            .offset(x: 16 * unit, y: 18 * unit)
        }
        .frame(width: size, height: size)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }

    private func line(width: CGFloat, opacity: Double, start: CGFloat, unit: CGFloat) -> some View {
        let progress = min(max((drawProgress - start) / 0.35, 0), 1)
        return Capsule()
            .fill(mint.opacity(opacity))
            .frame(width: width * unit * progress, height: 2.5 * unit)
            .frame(width: width * unit, alignment: .leading)
    }
}

private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY - rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.08))
        return path
    }
}

/// Launch animation: the receipt draws itself, the check pops, the name fades in.
struct SplashView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draw: CGFloat = 0
    @State private var badge: CGFloat = 0
    @State private var showName = false
    @State private var glow = false

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.05).ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.06, green: 0.73, blue: 0.51).opacity(0.25))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .scaleEffect(glow ? 1.15 : 0.7)
                .opacity(glow ? 1 : 0)

            VStack(spacing: 22) {
                QattahLogoMark(drawProgress: draw, badgeProgress: badge, size: 132)
                    .shadow(color: .black.opacity(0.4), radius: 24, y: 12)

                VStack(spacing: 6) {
                    (Text("قطّ").foregroundStyle(.white)
                     + Text("ه").foregroundStyle(Color(red: 0.2, green: 0.83, blue: 0.6)))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                    Text("وين قطّتكم؟")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .opacity(showName ? 1 : 0)
                .offset(y: showName ? 0 : 12)
            }
        }
        .task { await run() }
    }

    private func run() async {
        if reduceMotion {
            draw = 1; badge = 1; showName = true; glow = true
            try? await Task.sleep(for: .milliseconds(500))
            onFinished()
            return
        }
        withAnimation(.easeOut(duration: 0.9)) { glow = true }
        withAnimation(.easeInOut(duration: 0.85)) { draw = 1 }
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { badge = 1 }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.easeOut(duration: 0.45)) { showName = true }
        try? await Task.sleep(for: .milliseconds(750))
        onFinished()
    }
}
