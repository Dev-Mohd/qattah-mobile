import SwiftUI
import QattahKit

enum WhatsApp {
    /// A wa.me link that opens a chat with `phone` and the message pre-filled.
    static func url(phone: String?, text: String) -> URL? {
        guard let phone, let digits = PhoneNumber.whatsAppDigits(phone) else { return nil }
        var components = URLComponents(string: "https://wa.me/\(digits)")
        components?.queryItems = [URLQueryItem(name: "text", value: text)]
        return components?.url
    }
}

/// Sends each debtor a personal reminder, one tap per person
/// (iOS does not allow sending messages automatically).
struct RemindAllView: View {
    let snapshot: ListSnapshot
    let debtors: [MemberBalance]
    private var listName: String { snapshot.list.name }

    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var sent: Set<String> = []
    @State private var sharing: (url: URL, message: String)?

    var body: some View {
        NavigationStack {
            List {
                if settings.paymentDetails.isEmpty {
                    Section {
                        Label("أضف رقم الآيبان أو STC Pay من الإعدادات ليظهر في رسائل التذكير",
                              systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(debtors) { row in
                        let message = ShareMessageBuilder.reminderMessage(listName: listName, balance: row,
                                                                          payment: settings.paymentDetails)
                        HStack(spacing: 12) {
                            Image(systemName: sent.contains(row.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(sent.contains(row.id) ? Color.credit : .secondary)
                            VStack(alignment: .leading) {
                                Text(row.member.name)
                                MoneyText(money: row.net, font: .caption).foregroundStyle(Color.owes)
                            }
                            Spacer()
                            Button {
                                if let url = try? MemberStatementRenderer.render(
                                    snapshot: snapshot, member: row.member, balance: row,
                                    payment: settings.paymentDetails) {
                                    sent.insert(row.id)
                                    sharing = (url, message)
                                }
                            } label: {
                                Image(systemName: "doc.richtext")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("كشف حساب PDF")
                            if let url = WhatsApp.url(phone: row.member.phone, text: message) {
                                Button {
                                    sent.insert(row.id)
                                    openURL(url)
                                } label: {
                                    Label("واتساب", systemImage: "message.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            } else {
                                ShareLink(item: message) {
                                    Label("إرسال", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                                .simultaneousGesture(TapGesture().onEnded { sent.insert(row.id) })
                            }
                        }
                    }
                } footer: {
                    Text("زر 📄 يرسل لكل عضو كشف حساب PDF أنيق بمبالغه ووجباته. الأعضاء الذين لهم رقم جوال يُفتح لهم الواتساب مباشرة.")
                }
            }
            .sheet(item: Binding(get: { sharing.map { ShareItem(url: $0.url) } },
                                 set: { if $0 == nil { sharing = nil } })) { item in
                ShareSheet(items: [item.url, sharing?.message ?? ""])
            }
            .navigationTitle("تذكير \(debtors.count) أعضاء")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("تم") { dismiss() } }
            }
        }
    }
}
