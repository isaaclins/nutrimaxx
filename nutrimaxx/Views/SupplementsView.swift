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
            ScrollView {
                VStack(spacing: 14) {
                    GlassSearchField(text: $query, placeholder: "Search supplements")

                    if store.supplements.isEmpty {
                        EmptyStateCard(icon: "pills", title: "No Supplements",
                                       message: "Tap + to add a supplement.")
                            .padding(.top, 40)
                    } else {
                        GlassEffectContainer(spacing: 12) {
                            VStack(spacing: 12) {
                                ForEach(filtered) { supplement in
                                    supplementRow(supplement)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
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

    private func supplementRow(_ supplement: Supplement) -> some View {
        GlassRow {
            HStack(spacing: 12) {
                Button { store.toggleSupplement(supplement) } label: {
                    Image(systemName: supplement.takenToday ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(supplement.takenToday ? Theme.accent : Color.secondary)
                }
                .buttonStyle(.plain)

                Button { editor = .edit(supplement) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(supplement.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                            Text(supplement.frequency).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(supplement.time).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                if let idx = store.supplements.firstIndex(where: { $0.id == supplement.id }) {
                    store.deleteSupplements(at: IndexSet(integer: idx))
                }
            } label: { Label("Delete", systemImage: "trash") }
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
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(existing == nil ? "New Supplement" : "Edit Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func save() {
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: time)
        if let existing {
            var updated = existing
            updated.name = name.trimmingCharacters(in: .whitespaces)
            updated.frequency = frequency
            updated.time = timeString
            store.updateSupplement(updated)
        } else {
            store.addSupplement(Supplement(name: name.trimmingCharacters(in: .whitespaces),
                                           frequency: frequency, time: timeString))
        }
        Task { await NotificationManager.shared.requestAuthorizationIfNeeded() }
        dismiss()
    }

    private static func defaultTime() -> Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }
    private static func parse(_ string: String) -> Date {
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
        return formatter.date(from: string) ?? defaultTime()
    }
}
