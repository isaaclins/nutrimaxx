import SwiftUI

struct RecipesView: View {
    @EnvironmentObject var store: AppStore

    @State private var query = ""
    @State private var showAdd = false

    private var filtered: [Recipe] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return store.recipes }
        return store.recipes.filter { $0.name.lowercased().contains(text) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { recipe in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recipe.name)
                            Text("\(Format.grams(recipe.servings)) servings")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Format.kcal(recipe.caloriesPerServing)) kcal/serv")
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { store.deleteRecipes(at: $0) }
            }
            .searchable(text: $query, prompt: "Search")
            .navigationTitle("Recipes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddRecipeView().environmentObject(store)
            }
        }
    }
}

struct AddRecipeView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var servingsText = "1"
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""

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
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let recipe = Recipe(
                            name: name.trimmingCharacters(in: .whitespaces),
                            servings: Double(servingsText) ?? 1,
                            nutrients: Nutrients(
                                calories: Double(caloriesText) ?? 0,
                                protein: Double(proteinText) ?? 0,
                                carbs: Double(carbsText) ?? 0,
                                fat: Double(fatText) ?? 0
                            )
                        )
                        store.addRecipe(recipe)
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
