import SwiftUI

/// Reusable food chooser: favorites, recents, custom foods, and OpenFoodFacts
/// search with pagination. Calls `onSelect` with the chosen product.
struct FoodPickerView: View {
    @EnvironmentObject var store: AppStore
    var onSelect: (FoodProduct) -> Void

    @State private var query = ""
    @State private var results: [FoodProduct] = []
    @State private var page = 1
    @State private var canLoadMore = false
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var showCustom = false

    private var isSearchingText: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        List {
            Section {
                TextField("Search foods", text: $query)
                    .textInputAutocapitalization(.never)
                    .onSubmit { runSearch(reset: true) }
                    .onChange(of: query) { _, _ in scheduleSearch() }
            }

            if isSearchingText {
                searchResults
            } else {
                catalog
            }
        }
        .sheet(isPresented: $showCustom) {
            CustomFoodView().environmentObject(store)
        }
    }

    // MARK: - Catalog (no query)

    @ViewBuilder private var catalog: some View {
        if !store.favoriteFoods.isEmpty {
            Section("Favorites") { ForEach(store.favoriteFoods) { row($0.asProduct) } }
        }
        if !store.recentFoods.isEmpty {
            Section("Recent") { ForEach(store.recentFoods.prefix(15).map { $0 }) { row($0.asProduct) } }
        }
        if !store.customFoods.isEmpty {
            Section("Custom") { ForEach(store.customFoods) { row($0.asProduct) } }
        }
        Section {
            Button {
                showCustom = true
            } label: {
                Label("Create Custom Food", systemImage: "plus")
            }
        }
    }

    // MARK: - Search results

    @ViewBuilder private var searchResults: some View {
        if isSearching && results.isEmpty {
            HStack { ProgressView(); Text("Searching...") }
        }
        if let errorMessage {
            Text(errorMessage).foregroundStyle(.red)
        }
        if !results.isEmpty {
            Section("Results") {
                ForEach(results) { row($0) }
                if canLoadMore {
                    Button {
                        loadMore()
                    } label: {
                        if isSearching { HStack { ProgressView(); Text("Loading...") } }
                        else { Text("Load more") }
                    }
                }
            }
        }
    }

    // MARK: - Row

    private func row(_ product: FoodProduct) -> some View {
        HStack {
            Button {
                onSelect(product)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name).foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        if let brand = product.brand { Text(brand) }
                        Text("\(Format.kcal(product.per100g.calories)) kcal / 100 g")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                store.toggleFavorite(name: product.name, brand: product.brand,
                                     per100g: product.per100g, barcode: product.barcode)
            } label: {
                Image(systemName: store.isFavorite(name: product.name, brand: product.brand, barcode: product.barcode) ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Search logic

    private func scheduleSearch() {
        searchTask?.cancel()
        let text = query
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            if text == query { runSearch(reset: true) }
        }
    }

    private func runSearch(reset: Bool) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { results = []; return }
        if reset { page = 1; results = [] }
        isSearching = true
        errorMessage = nil
        let requestedPage = page
        Task {
            do {
                let found = try await OpenFoodFactsAPI.shared.search(text, page: requestedPage)
                await MainActor.run {
                    if requestedPage == 1 { results = found } else { results += found }
                    canLoadMore = found.count >= 25
                    isSearching = false
                    if results.isEmpty { errorMessage = "No results" }
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    errorMessage = "Could not reach OpenFoodFacts."
                }
            }
        }
    }

    private func loadMore() {
        page += 1
        runSearch(reset: false)
    }
}

/// Create a custom food (per-100g macros) saved to the catalog.
struct CustomFoodView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                }
                Section("Per 100 g") {
                    field("Calories", $caloriesText, unit: "kcal")
                    field("Protein", $proteinText, unit: "g")
                    field("Carbs", $carbsText, unit: "g")
                    field("Fat", $fatText, unit: "g")
                }
            }
            .navigationTitle("Custom Food")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addCustomFood(
                            name: name.trimmingCharacters(in: .whitespaces),
                            brand: brand.isEmpty ? nil : brand,
                            per100g: Nutrients(
                                calories: Double(caloriesText) ?? 0,
                                protein: Double(proteinText) ?? 0,
                                carbs: Double(carbsText) ?? 0,
                                fat: Double(fatText) ?? 0))
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

    private func field(_ label: String, _ text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text(unit).foregroundStyle(.secondary)
        }
    }
}
