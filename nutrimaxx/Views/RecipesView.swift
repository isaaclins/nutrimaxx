import SwiftUI

struct RecipesView: View {
    @EnvironmentObject var store: AppStore

    @State private var query = ""
    @State private var editor: RecipeEditorTarget?

    private var filtered: [Recipe] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return store.recipes }
        return store.recipes.filter { $0.name.lowercased().contains(text) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    GlassSearchField(text: $query, placeholder: "Search recipes")

                    if store.recipes.isEmpty {
                        EmptyStateCard(icon: "book", title: "No Recipes",
                                       message: "Tap + to create your first recipe.")
                            .padding(.top, 40)
                    } else {
                        GlassEffectContainer(spacing: 12) {
                            VStack(spacing: 12) {
                                ForEach(filtered) { recipe in
                                    Button { editor = .edit(recipe) } label: {
                                        GlassRow {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(recipe.name).font(.body.weight(.medium))
                                                        .foregroundStyle(.primary)
                                                    Text("\(Format.grams(recipe.servings)) servings")
                                                        .font(.caption).foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                                Text("\(Format.kcal(recipe.caloriesPerServing)) kcal/serv")
                                                    .font(.subheadline).foregroundStyle(Theme.accent)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteRecipe(recipe)
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Recipes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editor = .create } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editor) { target in
                RecipeEditorView(target: target).environmentObject(store)
            }
        }
    }
}

enum RecipeEditorTarget: Identifiable {
    case create
    case edit(Recipe)
    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let r): return r.id.uuidString
        }
    }
}

/// Create or edit a recipe from ingredients (or manual totals), and log servings.
struct RecipeEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private let existing: Recipe?

    @State private var name: String
    @State private var servingsText: String
    @State private var ingredients: [RecipeIngredient]
    @State private var caloriesText: String
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String
    @State private var logMeal: MealType = .dinner
    @State private var logServingsText = "1"
    @State private var showPicker = false
    @State private var pendingProduct: FoodProduct?

    init(target: RecipeEditorTarget) {
        switch target {
        case .create:
            existing = nil
            _name = State(initialValue: "")
            _servingsText = State(initialValue: "1")
            _ingredients = State(initialValue: [])
            _caloriesText = State(initialValue: "")
            _proteinText = State(initialValue: "")
            _carbsText = State(initialValue: "")
            _fatText = State(initialValue: "")
        case .edit(let recipe):
            existing = recipe
            _name = State(initialValue: recipe.name)
            _servingsText = State(initialValue: Format.grams(recipe.servings))
            _ingredients = State(initialValue: recipe.ingredients)
            _caloriesText = State(initialValue: Format.grams(recipe.nutrients.calories))
            _proteinText = State(initialValue: Format.grams(recipe.nutrients.protein))
            _carbsText = State(initialValue: Format.grams(recipe.nutrients.carbs))
            _fatText = State(initialValue: Format.grams(recipe.nutrients.fat))
        }
    }

    private var manualNutrients: Nutrients {
        Nutrients(calories: Double(caloriesText) ?? 0, protein: Double(proteinText) ?? 0,
                  carbs: Double(carbsText) ?? 0, fat: Double(fatText) ?? 0)
    }
    private var builtRecipe: Recipe {
        Recipe(id: existing?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespaces),
               servings: Double(servingsText) ?? 1, nutrients: manualNutrients, ingredients: ingredients)
    }
    private var totals: Nutrients { builtRecipe.effectiveNutrients }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $name)
                    HStack {
                        Text("Servings"); Spacer()
                        TextField("1", text: $servingsText)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                Section("Ingredients") {
                    ForEach(ingredients) { ingredient in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ingredient.name)
                                Text("\(Format.grams(ingredient.grams)) g")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Format.kcal(ingredient.nutrients.calories)) kcal")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }
                    Button { showPicker = true } label: { Label("Add ingredient", systemImage: "plus") }
                }
                if ingredients.isEmpty {
                    Section("Totals (whole recipe)") {
                        field("Calories", $caloriesText, unit: "kcal")
                        field("Protein", $proteinText, unit: "g")
                        field("Carbs", $carbsText, unit: "g")
                        field("Fat", $fatText, unit: "g")
                    }
                } else {
                    Section("Totals (from ingredients)") {
                        LabeledContent("Calories", value: "\(Format.kcal(totals.calories)) kcal")
                        LabeledContent("Protein", value: "\(Format.grams(totals.protein)) g")
                        LabeledContent("Carbs", value: "\(Format.grams(totals.carbs)) g")
                        LabeledContent("Fat", value: "\(Format.grams(totals.fat)) g")
                    }
                }
                if existing != nil {
                    Section("Log to a meal") {
                        Picker("Meal", selection: $logMeal) {
                            ForEach(MealType.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }
                        HStack {
                            Text("Servings"); Spacer()
                            TextField("1", text: $logServingsText)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                        Button("Add to Log") {
                            store.logRecipe(builtRecipe, servings: Double(logServingsText) ?? 1,
                                            to: logMeal, on: store.selectedDate)
                            dismiss()
                        }
                    }
                    Section {
                        Button("Delete Recipe", role: .destructive) {
                            if let existing { store.deleteRecipe(existing) }
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(existing == nil ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if existing == nil { store.addRecipe(builtRecipe) } else { store.updateRecipe(builtRecipe) }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $showPicker) {
                NavigationStack {
                    FoodPickerView { product in pendingProduct = product; showPicker = false }
                        .navigationTitle("Add Ingredient")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showPicker = false } }
                        }
                }
                .environmentObject(store)
            }
            .sheet(item: $pendingProduct) { product in
                IngredientAmountView(product: product) { ingredient in
                    ingredients.append(ingredient); pendingProduct = nil
                }
            }
        }
    }

    private func field(_ label: String, _ text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label); Spacer()
            TextField("0", text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
            Text(unit).foregroundStyle(.secondary)
        }
    }
}

/// Choose grams for an ingredient being added to a recipe.
struct IngredientAmountView: View {
    @Environment(\.dismiss) private var dismiss
    let product: FoodProduct
    var onAdd: (RecipeIngredient) -> Void

    @State private var gramsText = "100"
    private var grams: Double { Double(gramsText) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ingredient") {
                    Text(product.name)
                    if let brand = product.brand { Text(brand).foregroundStyle(.secondary) }
                }
                Section("Amount") {
                    HStack {
                        TextField("Grams", text: $gramsText).keyboardType(.decimalPad)
                        Text("g").foregroundStyle(.secondary)
                    }
                }
                Section("Adds") {
                    LabeledContent("Calories", value: "\(Format.kcal(product.per100g.scaled(toGrams: grams).calories)) kcal")
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Amount")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { onAdd(RecipeIngredient(name: product.name, grams: grams, per100g: product.per100g)) }
                        .disabled(grams <= 0)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
