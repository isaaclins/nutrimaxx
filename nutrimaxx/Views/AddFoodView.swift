import SwiftUI

/// Search OpenFoodFacts, pick a product, choose a gram amount, and log it to a meal.
struct AddFoodView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var meal: MealType
    var date: Date

    @State private var query = ""
    @State private var results: [FoodProduct] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    @State private var selected: FoodProduct?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Search foods", text: $query)
                        .textInputAutocapitalization(.never)
                        .onSubmit(runSearch)
                        .onChange(of: query) { _, _ in scheduleSearch() }
                }

                if isSearching {
                    HStack { ProgressView(); Text("Searching...") }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }

                ForEach(results) { product in
                    Button {
                        selected = product
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                            HStack(spacing: 8) {
                                if let brand = product.brand {
                                    Text(brand)
                                }
                                Text("\(Format.kcal(product.per100g.calories)) kcal / 100 g")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Add to \(meal.rawValue.capitalized)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selected) { product in
                LogAmountView(product: product, meal: meal, date: date) { dismiss() }
                    .environmentObject(store)
            }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let text = query
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            if text == query { runSearch() }
        }
    }

    private func runSearch() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { results = []; return }
        isSearching = true
        errorMessage = nil
        Task {
            do {
                let found = try await OpenFoodFactsAPI.shared.search(text)
                await MainActor.run {
                    results = found
                    isSearching = false
                    if found.isEmpty { errorMessage = "No results" }
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    errorMessage = "Could not reach OpenFoodFacts."
                }
            }
        }
    }
}

/// Choose an amount for a selected product and confirm logging it.
struct LogAmountView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var health: HealthManager
    @Environment(\.dismiss) private var dismiss

    let product: FoodProduct
    let meal: MealType
    var date: Date
    var onLogged: () -> Void

    @State private var gramsText = "100"

    private var grams: Double { Double(gramsText) ?? 0 }
    private var scaled: Nutrients { product.per100g.scaled(toGrams: grams) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    Text(product.name)
                    if let brand = product.brand { Text(brand).foregroundStyle(.secondary) }
                }
                Section("Amount") {
                    HStack {
                        TextField("Grams", text: $gramsText)
                            .keyboardType(.decimalPad)
                        Text("g").foregroundStyle(.secondary)
                    }
                }
                Section("Totals") {
                    LabeledContent("Calories", value: "\(Format.kcal(scaled.calories)) kcal")
                    LabeledContent("Protein", value: "\(Format.grams(scaled.protein)) g")
                    LabeledContent("Carbs", value: "\(Format.grams(scaled.carbs)) g")
                    LabeledContent("Fat", value: "\(Format.grams(scaled.fat)) g")
                }
            }
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let entry = FoodEntry(name: product.name, meal: meal, grams: grams,
                                              nutrients: scaled, date: date,
                                              basePer100g: product.per100g)
                        store.addEntry(entry)
                        health.saveNutrition(for: entry)
                        onLogged()
                    }
                    .disabled(grams <= 0)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
