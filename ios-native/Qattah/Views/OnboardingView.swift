import SwiftUI

/// First-launch walkthrough (same four steps as the Flutter version).
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private struct Page {
        let icon: String
        let title: String
        let body: String
        let points: [String]
    }

    private let pages: [Page] = [
        Page(icon: "person.3.fill", title: "أنشئ قائمة للمجموعة",
             body: "القائمة هي مكان الفريق: فطور الدوام، قهوة المكتب، أو أي مجموعة تتقاسم المصاريف.",
             points: ["اكتب اسم القائمة", "أضف أعضاء المجموعة", "حدد الوجبات وسعرها المعتاد"]),
        Page(icon: "checklist.checked", title: "اختر الحاضرين",
             body: "عند تسجيل وجبة يتذكر قطّه من حضر آخر مرة ويحسب النصيب على الحاضرين فقط بالهللة.",
             points: ["اختر نوع الوجبة", "عدّل الحاضرين إن لزم", "اضغط حفظ"]),
        Page(icon: "banknote.fill", title: "سجّل السداد",
             body: "إذا دفع العضو كامل المبلغ أو جزءاً منه سجّله من الأرصدة ويبقى المتبقي واضحاً.",
             points: ["اضغط على اسم العضو", "المبلغ الكامل جاهز تلقائياً", "أرسل له تذكيراً بسحبة"]),
        Page(icon: "chart.bar.doc.horizontal.fill", title: "شارك وراجع",
             body: "أرسل الأرصدة برسالة جاهزة لواتساب، وصدّر تقريراً شهرياً PDF بضغطة.",
             points: ["رسالة الأرصدة للمجموعة", "تقرير شهري PDF", "تذكير يومي ذكي"]),
    ]

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("تخطي", action: onFinish)
                    .opacity(page < pages.count - 1 ? 1 : 0)
            }
            .padding()

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index], number: index + 1).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "التالي" : "ابدأ الآن")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
    }

    private func pageView(_ page: Page, number: Int) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: page.icon)
                .font(.system(size: 72))
                .foregroundStyle(Color.qattahAccent)
                .symbolRenderingMode(.hierarchical)
            Text("الخطوة \(number)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.qattahAccent)
            Text(page.title).font(.title.bold())
            Text(page.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(page.points, id: \.self) { point in
                    Label(point, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.primary, Color.qattahAccent)
                }
            }
            .padding(.top, 8)
            Spacer()
            Spacer()
        }
    }
}
