import SwiftUI

/// Shown when the encrypted database cannot be opened (for example after
/// moving to a new iPhone from a backup made by the old Flutter version).
struct RecoveryView: View {
    let error: Error
    let onStartFresh: () -> Void

    @State private var confirming = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.trianglebadge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            Text("تعذّر فتح البيانات")
                .font(.title2.bold())

            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("إذا كانت لديك نسخة احتياطية من قطّه يمكنك استعادتها بعد البدء من جديد. لن يُحذف الملف القديم.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("البدء من جديد") { confirming = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
        .confirmationDialog("ستبدأ بقائمة فارغة ويُحفظ الملف الحالي جانباً", isPresented: $confirming,
                            titleVisibility: .visible) {
            Button("البدء من جديد", role: .destructive, action: onStartFresh)
        }
    }
}
