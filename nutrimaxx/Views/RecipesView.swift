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
            List {
                ForEach(filtered) { recipe in
                    Button {
                        editor = .edit(recipe)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recipe.name).foregroundStyle(.primary)
                                Text("\(Format.grams(recipe.servings)) servings")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Format.kcal(recipe.caloriesPerServing)) kcal/serv")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { store.deleteRecipes(at: $0) }
            }
            .overlay {
                if store.recipes.isEmpty {
                    ContentUnavailableView("No Recipes", systemImage: "book",
                                           description: Text("Tap + to create your first recipe."))
                }
            }
            .searchable(text: $query, prompt: "Search")
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

/// Create or edit a recipe, and optionally log servings of it to a meal.
struct RecipeEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private let existing: Recipe?

    @State private var name: String
    @State private var servingsText: String
    @State private var caloriesText: String
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String

    @State private var logMeal: MealType = .dinner
    @State private var logServingsText = "1"

    init(target: RecipeEditorTarget) {
        switch target {
        case .create:
            existing = nil
            _name = State(initialValue: "")
            _servingsText = State(initialValue: "1")
            _caloriesText = State(initialValue: "")
            _proteinText = State(initialValue: "")
            _carbsText = State(initialValue: "")
            _fatText = State(initialValue: "")
        case .edit(let recipe):
            existing = recipe
            _name = State(initialValue: recipe.name)
            _servingsText = State(initialValue: Format.grams(recipe.servings))
            _caloriesText = State(initialValue: Format.grams(recipe.nutrients.calories))
            _proteinText = State(initialValue: Format.grams(recipe.nutrients.protein))
            _carbsText = State(initialValue: Format.grams(recipe.nutrients.carbs))
            _fatText = State(initialValue: Format.grams(recipe.nutrients.fat))
        }
    }

    private var builtRecipe: Recipe {
        Recipe(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            servings: Double(servingsText) ?? 1,
            nutrients: Nutrients(
                calories: Double(caloriesText) ?? 0,
                protein: Double(proteinText) ?? 0,
                carbs: Double(carbsText) ?? 0,
                fat: Double(fatText) ?? 0
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $name)
                    HStack {
                        Text("Servings")
                        Spacer()
                        TextField("1", text: $servingsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("Totals (whole recipe)") {
                    field("Calories", $caloriesText, unit: "kcal")
                    field("Protein", $proteinText, unit: "g")
                    field("Carbs", $carbsText, unit: "g")
                    field("Fat", $fatText, unit: "g")
                }

                if existing != nil {
                    Section("Log to a meal") {
                        Picker("Meal", selection: $logMeal) {
                            ForEach(MealType.allCases) { Text($0.rawValue.capitalized).tag($0) }
                        }
                        HStack {
                            Text("Servings")
                            Spacer()
                            TextField("1", text: $logServingsText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        Button("Add to Log") {
                            store.logRecipe(builtRecipe, servings: Double(logServingsText) ?? 1,
                                            to: logMeal, on: store.selectedDate)
                            dismiss()
                        }
                    }
                    Section {
                        Button("Delete Recipe", role: .destructive) {
                            if let existing { store.deleteRecipes(at: IndexSet(store.recipes.firstIndex(where: { $0.id == existing.id }).map { [$0] } ?? [])) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if existing == nil { store.addRecipe(builtRecipe) }
                        else { store.updateRecipe(builtRecipe) }
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
