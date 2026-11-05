import SwiftUI
import UniformTypeIdentifiers
import QattahKit

struct SettingsView: View {
    @Environment(\.store) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var backupURL: URL?
    @State private var importing = false
    @State private var pendingImport: (url: URL, summary: BackupService.Summary)?
    @State private var confirmDeleteAll = false
    @State private var showOnboarding = false
    @State private var message: String?

    private var backup: BackupService { BackupService(database: store.database) }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("المظهر") {
                    Picker("المظهر", selection: $settings.appearance) {
                        ForEach(AppSettings.Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("تذكير يومي", isOn: Binding(
                        get: { settings.reminderEnabled },
                        set: { newValue in Task { await setReminder(newValue) } }
                    ))
                    if settings.reminderEnabled {
                        DatePicker("وقت التذكير", selection: $settings.reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("التذكيرات")
                } footer: {
                    Text("لا يصلك التذكير إذا سجّلت وجبة في نفس اليوم.")
                }

                Section {
                    Button {
                        exportBackup()
                    } label: {
                        Label("تصدير نسخة احتياطية", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        importing = true
                    } label: {
                        Label("استيراد نسخة احتياطية", systemImage: "square.and.arrow.down")
                    }
                    Button(role: .destructive) {
                        confirmDeleteAll = true
                    } label: {
                        Label("حذف كل البيانات", systemImage: "trash")
                    }
                } header: {
                    Text("البيانات")
                } footer: {
                    Text("ملف النسخة الاحتياطية غير مشفّر. احفظه في مكان آمن مثل iCloud Drive ولا تشاركه مع أحد.")
                }

                Section("عن التطبيق") {
                    NavigationLink("سياسة الخصوصية") { LegalView(document: .privacy) }
                    NavigationLink("الشروط والأحكام") { LegalView(document: .terms) }
                    NavigationLink("عن قطّه") { AboutView() }
                    Button("الجولة التعريفية") { showOnboarding = true }
                }
            }
            .navigationTitle("الإعدادات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("تم") { dismiss() } }
            }
            .sheet(item: Binding(get: { backupURL.map(IdentifiedURL.init) }, set: { backupURL = $0?.url })) { item in
                ShareSheet(items: [item.url])
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .data]) { result in
                handleImportSelection(result)
            }
            .confirmationDialog(importTitle, isPresented: .constant(pendingImport != nil), titleVisibility: .visible) {
                Button("استبدال بياناتي بهذه النسخة", role: .destructive) { restore() }
                Button("إلغاء", role: .cancel) { pendingImport = nil }
            }
            .confirmationDialog("سيتم حذف كل القوائم والأعضاء والوجبات والسدادات من هذا الجهاز",
                                isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("حذف كل البيانات", role: .destructive) { deleteAll() }
            }
            .alert("قطّه", isPresented: .constant(message != nil)) {
                Button("حسناً") { message = nil }
            } message: {
                Text(message ?? "")
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView { showOnboarding = false }
            }
        }
    }

    private var importTitle: String {
        guard let summary = pendingImport?.summary else { return "" }
        return "تحتوي النسخة على \(summary.lists) قائمة و\(summary.members) عضو و\(summary.meals) وجبة و\(summary.payments) سداد. ستُستبدل بياناتك الحالية بالكامل."
    }

    private func setReminder(_ enabled: Bool) async {
        if enabled {
            guard await ReminderScheduler.requestAuthorization() else {
                message = "فعّل الإشعارات لتطبيق قطّه من إعدادات الجهاز"
                return
            }
        }
        settings.reminderEnabled = enabled
    }

    private func exportBackup() {
        do {
            backupURL = try backup.export()
        } catch {
            message = "تعذّر تصدير النسخة: \(error.localizedDescription)"
        }
    }

    private func handleImportSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                pendingImport = (url, try backup.inspect(url))
            } catch {
                message = error.localizedDescription
            }
        case .failure(let error):
            message = error.localizedDescription
        }
    }

    private func restore() {
        guard let url = pendingImport?.url else { return }
        pendingImport = nil
        do {
            try backup.restore(from: url)
            Haptics.success()
            message = "تم استيراد النسخة الاحتياطية"
        } catch {
            message = "تعذّر الاستيراد: \(error.localizedDescription)"
        }
    }

    private func deleteAll() {
        do {
            try backup.deleteAllData()
            message = "تم حذف كل البيانات"
        } catch {
            message = "تعذّر حذف البيانات: \(error.localizedDescription)"
        }
    }
}

private struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// UIKit share sheet (ShareLink needs the file before the button appears;
/// backups are created on tap instead).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.qattahAccent)
                    Text("قطّه").font(.largeTitle.bold())
                    Text("تنظيم وجبات العمل وحساب النصيب والسداد بوضوح")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Text("الإصدار \(version)").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .listRowBackground(Color.clear)
            }
            Section {
                Link(destination: URL(string: "https://instagram.com/qattah.app")!) {
                    LabeledContent("إنستغرام التطبيق", value: "@qattah.app")
                }
                Link(destination: URL(string: "https://dev-mohd.com")!) {
                    LabeledContent("صفحة المطور", value: "dev-mohd.com")
                }
            }
            Section {
                Text("صنع بواسطة DevMohd").frame(maxWidth: .infinity).foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("عن قطّه")
        .navigationBarTitleDisplayMode(.inline)
    }
}
