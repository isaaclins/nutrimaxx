import SwiftUI

/// Edit an already-logged food entry: change name, meal, and amount.
/// If the entry came from OpenFoodFacts (has a per-100g base) the macros
/// re-scale with the grams; otherwise nutrients are edited directly.
struct EditFoodEntryView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var health: HealthManager
    @Environment(\.dismiss) private var dismiss

    @State private var draft: FoodEntry
    @State private var gramsText: String
    @State private var caloriesText: String
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String

    init(entry: FoodEntry) {
        _draft = State(initialValue: entry)
        _gramsText = State(initialValue: Format.grams(entry.grams))
        _caloriesText = State(initialValue: Format.grams(entry.nutrients.calories))
        _proteinText = State(initialValue: Format.grams(entry.nutrients.protein))
        _carbsText = State(initialValue: Format.grams(entry.nutrients.carbs))
        _fatText = State(initialValue: Format.grams(entry.nutrients.fat))
    }

    private var hasBase: Bool { draft.basePer100g != nil }
    private var grams: Double { Double(gramsText) ?? 0 }

    private var scaled: Nutrients {
        if let base = draft.basePer100g {
            return base.scaled(toGrams: grams)
        }
        return Nutrients(
            calories: Double(caloriesText) ?? 0,
            protein: Double(proteinText) ?? 0,
            carbs: Double(carbsText) ?? 0,
            fat: Double(fatText) ?? 0
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $draft.name)
                    Picker("Meal", selection: $draft.meal) {
                        ForEach(MealType.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                }

                if hasBase {
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
                } else {
                    Section("Nutrients") {
                        numberRow("Calories", $caloriesText, unit: "kcal")
                        numberRow("Protein", $proteinText, unit: "g")
                        numberRow("Carbs", $carbsText, unit: "g")
                        numberRow("Fat", $fatText, unit: "g")
                    }
                }

                Section {
                    Button("Delete Entry", role: .destructive) {
                        health.deleteNutrition(entryID: draft.id)
                        store.deleteEntry(draft)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.grams = hasBase ? grams : draft.grams
                        draft.nutrients = scaled
                        store.updateEntry(draft)
                        health.updateNutrition(for: draft)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func numberRow(_ label: String, _ text: Binding<String>, unit: String) -> some View {
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
