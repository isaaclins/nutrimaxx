import Foundation
import Combine

/// Local-only persisted application state. Everything is stored as JSON in
/// UserDefaults so the app survives relaunches with no backend.
final class AppStore: ObservableObject {
    @Published var entries: [FoodEntry] { didSet { save() } }
    @Published var recipes: [Recipe] { didSet { save() } }
    @Published var supplements: [Supplement] { didSet { save() } }
    @Published var goals: Goals { didSet { save() } }
    @Published var units: UnitSystem { didSet { save() } }
    @Published var dietaryNotes: String { didSet { save() } }
    @Published var appleHealthConnected: Bool { didSet { save() } }

    private let defaultsKey = "nutrimaxx.state.v2"

    init() {
        if let saved = Self.load() {
            entries = saved.entries
            recipes = saved.recipes
            supplements = saved.supplements
            goals = saved.goals
            units = saved.units
            dietaryNotes = saved.dietaryNotes
            appleHealthConnected = saved.appleHealthConnected
        } else {
            // Fresh install: start empty. Users add their own foods, recipes,
            // supplements, and connect Apple Health from Settings.
            entries = []
            recipes = []
            supplements = []
            goals = Goals()
            units = .metric
            dietaryNotes = ""
            appleHealthConnected = false
        }
    }

    // MARK: - Derived totals

    var consumed: Nutrients {
        entries.reduce(Nutrients()) { $0 + $1.nutrients }
    }

    func entries(for meal: MealType) -> [FoodEntry] {
        entries.filter { $0.meal == meal }
    }

    // MARK: - Mutations

    func addEntry(_ entry: FoodEntry) { entries.append(entry) }

    func deleteEntries(for meal: MealType, at offsets: IndexSet) {
        let mealEntries = entries(for: meal)
        let ids = offsets.map { mealEntries[$0].id }
        entries.removeAll { ids.contains($0.id) }
    }

    func addRecipe(_ recipe: Recipe) { recipes.append(recipe) }
    func deleteRecipes(at offsets: IndexSet) { recipes.remove(atOffsets: offsets) }

    func addSupplement(_ supplement: Supplement) { supplements.append(supplement) }
    func deleteSupplements(at offsets: IndexSet) { supplements.remove(atOffsets: offsets) }
    func toggleSupplement(_ supplement: Supplement) {
        guard let idx = supplements.firstIndex(where: { $0.id == supplement.id }) else { return }
        supplements[idx].takenToday.toggle()
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var entries: [FoodEntry]
        var recipes: [Recipe]
        var supplements: [Supplement]
        var goals: Goals
        var units: UnitSystem
        var dietaryNotes: String
        var appleHealthConnected: Bool
    }

    private func snapshot() -> Snapshot {
        Snapshot(entries: entries, recipes: recipes, supplements: supplements,
                 goals: goals, units: units, dietaryNotes: dietaryNotes,
                 appleHealthConnected: appleHealthConnected)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot()) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private static func load() -> Snapshot? {
        guard let data = UserDefaults.standard.data(forKey: "nutrimaxx.state.v2"),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return nil }
        return snap
    }
}
