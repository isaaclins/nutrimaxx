import SwiftUI

struct LogView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var health: HealthManager

    @State private var showAddFood = false
    @State private var addMeal: MealType = .breakfast
    @State private var editingEntry: FoodEntry?
    @State private var showScanner = false
    @State private var scannedProduct: FoodProduct?
    @State private var scanError: String?
    @State private var showAddMealChooser = false
    @State private var showScanMealChooser = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    DayNavigator()

                    GlassEffectContainer(spacing: 18) {
                        VStack(spacing: 18) {
                            ForEach(MealType.allCases) { meal in
                                mealCard(meal)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Log")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showAddMealChooser = true } label: { Image(systemName: "plus") }
                    Button { showScanMealChooser = true } label: { Image(systemName: "barcode.viewfinder") }
                }
            }
            .confirmationDialog("Add to which meal?", isPresented: $showAddMealChooser, titleVisibility: .visible) {
                ForEach(MealType.allCases) { meal in
                    Button(meal.rawValue.capitalized) { addMeal = meal; showAddFood = true }
                }
            }
            .confirmationDialog("Scan into which meal?", isPresented: $showScanMealChooser, titleVisibility: .visible) {
                ForEach(MealType.allCases) { meal in
                    Button(meal.rawValue.capitalized) { addMeal = meal; showScanner = true }
                }
            }
            .sheet(isPresented: $showAddFood) {
                AddFoodView(meal: addMeal, date: store.selectedDate).environmentObject(store)
            }
            .sheet(item: $editingEntry) { entry in
                EditFoodEntryView(entry: entry).environmentObject(store)
            }
            .sheet(item: $scannedProduct) { product in
                LogAmountView(product: product, meal: addMeal, date: store.selectedDate) {
                    scannedProduct = nil
                }
                .environmentObject(store)
            }
            .fullScreenCover(isPresented: $showScanner) {
                BarcodeScannerView { code in showScanner = false; lookUp(barcode: code) }
                    onCancel: { showScanner = false }
            }
            .alert("Not found", isPresented: Binding(get: { scanError != nil }, set: { if !$0 { scanError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(scanError ?? "")
            }
        }
    }

    private func mealCard(_ meal: MealType) -> some View {
        let items = store.entries(for: meal, on: store.selectedDate)
        let total = items.reduce(0) { $0 + $1.nutrients.calories }
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(meal.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    Spacer()
                    if total > 0 {
                        Text("\(Format.kcal(total)) kcal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }

                if items.isEmpty {
                    Text("Nothing logged")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { entry in
                        Button { editingEntry = entry } label: {
                            HStack {
                                Text(entry.name).foregroundStyle(.primary)
                                Spacer()
                                Text("\(Format.kcal(entry.nutrients.calories)) kcal")
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                health.deleteNutrition(entryID: entry.id)
                                store.deleteEntry(entry)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                        if entry.id != items.last?.id { Divider().opacity(0.4) }
                    }
                }

                Button { addMeal = meal; showAddFood = true } label: {
                    Label("Add food", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.glass)
                .tint(Theme.accent)
            }
        }
    }

    private func lookUp(barcode: String) {
        Task {
            do {
                if let product = try await OpenFoodFactsAPI.shared.product(barcode: barcode) {
                    await MainActor.run { scannedProduct = product }
                } else {
                    await MainActor.run { scanError = "No product for barcode \(barcode)." }
                }
            } catch {
                await MainActor.run { scanError = "Could not reach OpenFoodFacts." }
            }
        }
    }
}
