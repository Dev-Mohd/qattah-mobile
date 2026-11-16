import SwiftUI
import TipKit

// Shared look for the app.
//
// Liquid Glass (iOS 26) is used only for the floating control layer — bottom
// actions, quick-action chips, toasts — never for content cards, following
// Apple's guidance. Older systems fall back to materials and standard styles.

@available(iOS 26.0, *)
private func makeGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass = Glass.regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

extension View {
    /// Floating capsule surface (chips, toasts).
    @ViewBuilder
    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(makeGlass(tint: tint, interactive: interactive), in: .capsule)
        } else {
            background(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.regularMaterial), in: Capsule())
        }
    }

    /// Floating rounded surface (banners).
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    /// The one main action of a screen.
    @ViewBuilder
    func primaryActionStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// Screen background shared by the inner screens: grouped background with
    /// a soft wash of the list's color at the top.
    func screenBackground(tint: Color = .qattahAccent) -> some View {
        modifier(ScreenBackground(tint: tint))
    }

    /// Home card → list screen zoom (iOS 18+).
    @ViewBuilder
    func zoomSource(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func zoomDestination(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

private struct ScreenBackground: ViewModifier {
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    Color(.systemGroupedBackground)
                    LinearGradient(colors: [tint.opacity(colorScheme == .dark ? 0.28 : 0.18), .clear],
                                   startPoint: .top, endPoint: .center)
                }
                .ignoresSafeArea()
            }
    }
}

// MARK: - Tips (TipKit)

/// Teaches the hidden gestures once each.
struct BalanceSwipeTip: Tip {
    var title: Text { Text("اسحب على العضو") }
    var message: Text? { Text("يميناً لتسجيل سداد، ويساراً لإرسال تذكير. واضغط عليه لعرض كشفه.") }
    var image: Image? { Image(systemName: "hand.draw") }
}

struct MealRepeatTip: Tip {
    var title: Text { Text("كرّر الوجبة بسحبة") }
    var message: Text? { Text("اسحب على أي وجبة لتكرارها اليوم بنفس الحضور، أو اضغط مطولاً لخيارات أكثر.") }
    var image: Image? { Image(systemName: "arrow.clockwise") }
}

struct ListMenuTip: Tip {
    var title: Text { Text("اضغط مطولاً على القائمة") }
    var message: Text? { Text("لتسجيل وجبة أو تعديل الاسم واللون بدون فتحها.") }
    var image: Image? { Image(systemName: "hand.tap") }
}

enum AppTips {
    static func configure() {
        try? Tips.configure([.displayFrequency(.daily)])
    }
}
