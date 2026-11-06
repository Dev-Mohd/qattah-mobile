import SwiftUI

/// App-wide success toast ("✓ سُجّلت الوجبة") shown at the top of the screen.
@MainActor
@Observable
final class Toaster {
    struct Toast: Equatable, Identifiable {
        let id = UUID()
        let message: String
        let symbol: String
    }

    private(set) var current: Toast?

    func show(_ message: String, symbol: String = "checkmark.circle.fill") {
        let toast = Toast(message: message, symbol: symbol)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { current = toast }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if current?.id == toast.id {
                withAnimation(.easeInOut(duration: 0.3)) { current = nil }
            }
        }
    }
}

struct ToastOverlay: View {
    @Environment(Toaster.self) private var toaster
    @State private var bounce = 0

    var body: some View {
        VStack {
            if let toast = toaster.current {
                HStack(spacing: 10) {
                    Image(systemName: toast.symbol)
                        .font(.title3)
                        .foregroundStyle(Color.credit)
                        .symbolEffect(.bounce, value: bounce)
                    Text(toast.message).font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                .onAppear { bounce += 1 }
                .onTapGesture { }
                .accessibilityAddTraits(.isStaticText)
            }
            Spacer()
        }
        .padding(.top, 8)
        .allowsHitTesting(false)
    }
}
