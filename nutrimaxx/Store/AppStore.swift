import Foundation
import Combine

/// Local-only persisted application state. Everything is stored as JSON in
/// UserDefaults so the app survives relaunches with no backend.
final class AppStore: ObservableObject {
    @Published var entries: [FoodEntry] { didSet { save() } }
    @Published var recipes: [Recipe] { didSet { save() } }
    @Published var supplements: [Supplement] { didSet { save(); rescheduleNotifications() } }
    @Published var goals: Goals { didSet { save() } }
    @Published var metrics: UserMetrics { didSet { save() } }
    @Published var units: UnitSystem { didSet { save() } }
    @Published var dietaryNotes: String { didSet { save() } }
    @Published var appleHealthConnected: Bool { didSet { save() } }
    @Published var hasOnboarded: Bool { didSet { save() } }

    /// Currently viewed day (not persisted). Dashboard and Log follow this.
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private let defaultsKey = "nutrimaxx.state.v4"

    init() {
        if let saved = Self.load() {
            entries = saved.entries
            recipes = saved.recipes
            supplements = saved.supplements
            goals = saved.goals
            metrics = saved.metrics
            units = saved.units
            dietaryNotes = saved.dietaryNotes
            appleHealthConnected = saved.appleHealthConnected
            hasOnboarded = saved.hasOnboarded
        } else {
            // Fresh install: start empty. Users set goals in onboarding and add
            // their own foods, recipes, and supplements.
            entries = []
            recipes = []
            supplements = []
            goals = Goals()
            metrics = UserMetrics()
            units = .metric
            dietaryNotes = ""
            appleHealthConnected = false
            hasOnboarded = false
        }
    }

    // MARK: - Day helpers

    func isSelectedDateToday() -> Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }

    func goToNextDay() {
        guard !isSelectedDateToday() else { return }
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }

    func goToToday() {
        selectedDate = Calendar.current.startOfDay(for: Date())
    }

    // MARK: - Derived totals (for the selected day)

    func entries(on day: Date) -> [FoodEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    func entries(for meal: MealType, on day: Date) -> [FoodEntry] {
        entries(on: day).filter { $0.meal == meal }
    }

    func consumed(on day: Date) -> Nutrients {
        entries(on: day).reduce(Nutrients()) { $0 + $1.nutrients }
    }

    var consumed: Nutrients { consumed(on: selectedDate) }

    // MARK: - Food entry mutations

    func addEntry(_ entry: FoodEntry) { entries.append(entry) }

    func updateEntry(_ entry: FoodEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
    }

    func deleteEntry(_ entry: FoodEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func deleteEntries(for meal: MealType, on day: Date, at offsets: IndexSet) {
        let mealEntries = entries(for: meal, on: day)
        let ids = offsets.map { mealEntries[$0].id }
        entries.removeAll { ids.contains($0.id) }
    }

    // MARK: - Recipe mutations

    func addRecipe(_ recipe: Recipe) { recipes.append(recipe) }

    func updateRecipe(_ recipe: Recipe) {
        guard let idx = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[idx] = recipe
    }

    func deleteRecipes(at offsets: IndexSet) { recipes.remove(atOffsets: offsets) }

    /// Log a number of servings of a recipe to a meal on a given day.
    func logRecipe(_ recipe: Recipe, servings: Double, to meal: MealType, on day: Date) {
        let perServing = Nutrients(
            calories: recipe.caloriesPerServing,
            protein: recipe.servings > 0 ? recipe.nutrients.protein / recipe.servings : recipe.nutrients.protein,
            carbs: recipe.servings > 0 ? recipe.nutrients.carbs / recipe.servings : recipe.nutrients.carbs,
            fat: recipe.servings > 0 ? recipe.nutrients.fat / recipe.servings : recipe.nutrients.fat
        )
        let total = Nutrients(
            calories: perServing.calories * servings,
            protein: perServing.protein * servings,
            carbs: perServing.carbs * servings,
            fat: perServing.fat * servings
        )
        addEntry(FoodEntry(name: recipe.name, meal: meal, grams: 0, nutrients: total, date: day))
    }

    // MARK: - Supplement mutations

    func addSupplement(_ supplement: Supplement) { supplements.append(supplement) }

    func updateSupplement(_ supplement: Supplement) {
        guard let idx = supplements.firstIndex(where: { $0.id == supplement.id }) else { return }
        supplements[idx] = supplement
    }

    func deleteSupplements(at offsets: IndexSet) { supplements.remove(atOffsets: offsets) }

    /// Toggle taken/not-taken for a supplement on a specific day (defaults to today).
    func toggleSupplement(_ supplement: Supplement, on day: Date = Date()) {
        guard let idx = supplements.firstIndex(where: { $0.id == supplement.id }) else { return }
        let dayStart = Calendar.current.startOfDay(for: day)
        if supplements[idx].isTaken(on: day) {
            supplements[idx].takenDates.removeAll { Calendar.current.isDate($0, inSameDayAs: day) }
        } else {
            supplements[idx].takenDates.append(dayStart)
        }
    }

    private func rescheduleNotifications() {
        NotificationManager.shared.reschedule(for: supplements)
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var entries: [FoodEntry]
        var recipes: [Recipe]
        var supplements: [Supplement]
        var goals: Goals
        var metrics: UserMetrics
        var units: UnitSystem
        var dietaryNotes: String
        var appleHealthConnected: Bool
        var hasOnboarded: Bool
    }

    private func snapshot() -> Snapshot {
        Snapshot(entries: entries, recipes: recipes, supplements: supplements,
                 goals: goals, metrics: metrics, units: units, dietaryNotes: dietaryNotes,
                 appleHealthConnected: appleHealthConnected, hasOnboarded: hasOnboarded)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot()) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private static func load() -> Snapshot? {
        guard let data = UserDefaults.standard.data(forKey: "nutrimaxx.state.v4"),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return nil }
        return snap
    }
}
