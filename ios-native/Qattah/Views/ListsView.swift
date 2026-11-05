import SwiftUI
import GRDB
import QattahKit

/// Home screen: all lists with how much is owed in each.
struct ListsView: View {
    @Environment(\.store) private var store
    @State private var summaries: [ListSummary] = []
    @State private var loaded = false
    @State private var newListName = ""
    @State private var showingNewList = false
    @State private var errorMessage: String?
    @State private var showingSettings = false
    @State private var path: [String] = []
    @State private var pendingDelete: ListSummary?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if loaded && summaries.isEmpty {
                    ContentUnavailableView {
                        Label("لا توجد قوائم بعد", systemImage: "fork.knife")
                    } description: {
                        Text("أنشئ قائمة لفطور الدوام أو غداء الفريق وابدأ بتسجيل الوجبات")
                    } actions: {
                        Button("إنشاء قائمة") { showingNewList = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(summaries) { summary in
                        NavigationLink(value: summary.list.id) {
                            ListRow(summary: summary)
                        }
                        .swipeActions {
                            Button(role: .destructive) { pendingDelete = summary } label: {
                                Label("حذف", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("قطّه")
            .navigationDestination(for: String.self) { listId in
                ListDetailView(listId: listId)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("الإعدادات", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewList = true
                    } label: {
                        Label("قائمة جديدة", systemImage: "plus")
                    }
                }
            }
            .alert("قائمة جديدة", isPresented: $showingNewList) {
                TextField("مثال: فطور الدوام", text: $newListName)
                Button("إنشاء") { createList() }
                Button("إلغاء", role: .cancel) { newListName = "" }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .onOpenURL { url in
                // From the widget: qattah://list/<id>
                guard url.scheme == "qattah", url.host == "list" else { return }
                showingSettings = false
                path = [url.lastPathComponent]
            }
            .confirmationDialog("سيتم حذف القائمة «\(pendingDelete?.list.name ?? "")» مع كل أعضائها ووجباتها وسداداتها",
                                isPresented: .constant(pendingDelete != nil), titleVisibility: .visible) {
                Button("حذف القائمة", role: .destructive) {
                    if let id = pendingDelete?.list.id {
                        Task { try? await store.deleteList(id: id) }
                    }
                    pendingDelete = nil
                }
                Button("إلغاء", role: .cancel) { pendingDelete = nil }
            }
            .alert("حدث خطأ", isPresented: .constant(errorMessage != nil)) {
                Button("حسناً") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task {
            do {
                for try await value in store.observeSummaries() {
                    summaries = value
                    loaded = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func createList() {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        newListName = ""
        guard !name.isEmpty else { return }
        Task {
            do {
                let list = QattahList(name: name)
                try await store.saveList(list)
                Haptics.success()
                path.append(list.id) // open the new list straight away
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ListRow: View {
    let summary: ListSummary

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: summary.list.color))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.list.name).font(.headline)
                Text("\(summary.memberCount) أعضاء" + (summary.lastMealDay.map { " · آخر وجبة \($0)" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if summary.totalOwed.isPositive {
                VStack(alignment: .trailing, spacing: 2) {
                    MoneyText(money: summary.totalOwed, font: .subheadline, weight: .semibold)
                        .foregroundStyle(Color.owes)
                    Text("مستحق").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
