import SwiftUI

struct SupplementsView: View {
    @EnvironmentObject var store: AppStore

    @State private var query = ""
    @State private var showAdd = false

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

                        VStack(alignment: .leading, spacing: 2) {
                            Text(supplement.name)
                            Text(supplement.frequency)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(supplement.time)
                            .foregroundStyle(.secondary)
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
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddSupplementView().environmentObject(store)
            }
        }
    }
}

struct AddSupplementView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var frequency = "Daily"
    @State private var time = Date()

    private let frequencies = ["Daily", "Twice Daily", "Weekly", "As Needed"]

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
            }
            .navigationTitle("New Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        let supplement = Supplement(
                            name: name.trimmingCharacters(in: .whitespaces),
                            frequency: frequency,
                            time: formatter.string(from: time)
                        )
                        store.addSupplement(supplement)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
