import SwiftUI

struct SupplementsView: View {
    @EnvironmentObject var store: AppStore

    @State private var query = ""
    @State private var editor: SupplementEditorTarget?

    private var filtered: [Supplement] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return store.supplements }
        return store.supplements.filter { $0.name.lowercased().contains(text) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { supplement in
                    HStack {
                        Button {
                            store.toggleSupplement(supplement)
                        } label: {
                            Image(systemName: supplement.takenToday ? "largecircle.fill.circle" : "circle")
                        }
                        .buttonStyle(.plain)

                        Button {
                            editor = .edit(supplement)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(supplement.name).foregroundStyle(.primary)
                                    Text(supplement.frequency)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(supplement.time)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { store.deleteSupplements(at: $0) }
            }
            .overlay {
                if store.supplements.isEmpty {
                    ContentUnavailableView("No Supplements", systemImage: "pills",
                                           description: Text("Tap + to add a supplement."))
                }
            }
            .searchable(text: $query, prompt: "Search")
            .navigationTitle("Supplements")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editor = .create } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editor) { target in
                SupplementEditorView(target: target).environmentObject(store)
            }
        }
    }
}

enum SupplementEditorTarget: Identifiable {
    case create
    case edit(Supplement)
    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let s): return s.id.uuidString
        }
    }
}

struct SupplementEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private let existing: Supplement?

    @State private var name: String
    @State private var frequency: String
    @State private var time: Date

    private let frequencies = ["Daily", "Twice Daily", "Weekly", "As Needed"]

    init(target: SupplementEditorTarget) {
        switch target {
        case .create:
            existing = nil
            _name = State(initialValue: "")
            _frequency = State(initialValue: "Daily")
            _time = State(initialValue: Self.defaultTime())
        case .edit(let supplement):
            existing = supplement
            _name = State(initialValue: supplement.name)
            _frequency = State(initialValue: supplement.frequency)
            _time = State(initialValue: Self.parse(supplement.time))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Supplement") {
                    TextField("Name", text: $name)
                    Picker("Frequency", selection: $frequency) {
                        ForEach(frequencies, id: \.self) { Text($0) }
                    }
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                }
                if existing != nil {
                    Section {
                        Button("Delete Supplement", role: .destructive) {
                            if let idx = store.supplements.firstIndex(where: { $0.id == existing?.id }) {
                                store.deleteSupplements(at: IndexSet(integer: idx))
                            }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Supplement" : "Edit Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: time)

        if let existing {
            var updated = existing
            updated.name = name.trimmingCharacters(in: .whitespaces)
            updated.frequency = frequency
            updated.time = timeString
            store.updateSupplement(updated)
        } else {
            let supplement = Supplement(
                name: name.trimmingCharacters(in: .whitespaces),
                frequency: frequency,
                time: timeString
            )
            store.addSupplement(supplement)
        }
        // Ask for notification permission if we still can (dismissed onboarding, etc.).
        Task { await NotificationManager.shared.requestAuthorizationIfNeeded() }
        dismiss()
    }

    private static func defaultTime() -> Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private static func parse(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: string) ?? defaultTime()
    }
}
