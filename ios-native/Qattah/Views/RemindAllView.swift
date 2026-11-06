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
    let listName: String
    let debtors: [MemberBalance]

    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var sent: Set<String> = []

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
                    Text("الأعضاء الذين لهم رقم جوال يُفتح لهم الواتساب مباشرة. أضف الرقم من تبويب الأعضاء.")
                }
            }
            .navigationTitle("تذكير \(debtors.count) أعضاء")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("تم") { dismiss() } }
            }
        }
    }
}
