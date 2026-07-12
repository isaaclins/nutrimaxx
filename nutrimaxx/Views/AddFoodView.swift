import SwiftUI

/// Pick a food (search / recent / favorite / custom), choose an amount, and log it.
struct AddFoodView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var meal: MealType
    var date: Date

    @State private var selected: FoodProduct?

    var body: some View {
        NavigationStack {
            FoodPickerView { product in
                selected = product
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
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let entry = FoodEntry(name: product.name, meal: meal, grams: grams,
                                              nutrients: scaled, date: date,
                                              basePer100g: product.per100g)
                        store.addEntry(entry)
                        store.recordUse(name: product.name, brand: product.brand,
                                        per100g: product.per100g, barcode: product.barcode)
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
