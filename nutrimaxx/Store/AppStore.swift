import Foundation
import Combine

/// Local-first persisted application state (JSON in UserDefaults), mirrored to
/// iCloud key-value storage so data survives reinstalls and syncs across devices.
final class AppStore: ObservableObject {
    @Published var entries: [FoodEntry] { didSet { save() } }
    @Published var recipes: [Recipe] { didSet { save() } }
    @Published var supplements: [Supplement] { didSet { save(); rescheduleNotifications() } }
    @Published var foods: [FoodItem] { didSet { save() } }
    @Published var goals: Goals { didSet { save() } }
    @Published var metrics: UserMetrics { didSet { save() } }
    @Published var units: UnitSystem { didSet { save() } }
    @Published var dietaryNotes: String { didSet { save() } }
    @Published var appleHealthConnected: Bool { didSet { save() } }
    @Published var hasOnboarded: Bool { didSet { save() } }
    @Published var iCloudEnabled: Bool { didSet { save() } }
    @Published var mealReminders: MealReminders { didSet { save(); NotificationManager.shared.scheduleMealReminders(mealReminders) } }

    /// Currently viewed day (not persisted). Dashboard and Log follow this.
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private let defaultsKey = "nutrimaxx.state.v6"
    private let kvStore = NSUbiquitousKeyValueStore.default
    private var isApplyingRemote = false

    init() {
        let local = Self.load()
        let remote = Self.loadFromICloud()
        // Pick whichever snapshot was saved most recently.
        let chosen: Snapshot? = {
            switch (local, remote) {
            case let (l?, r?): return r.savedAt > l.savedAt ? r : l
            case let (l?, nil): return l
            case let (nil, r?): return r
            default: return nil
            }
        }()

        if let snap = chosen {
            entries = snap.entries
            recipes = snap.recipes
            supplements = snap.supplements
            foods = snap.foods
            goals = snap.goals
            metrics = snap.metrics
            units = snap.units
            dietaryNotes = snap.dietaryNotes
            appleHealthConnected = snap.appleHealthConnected
            hasOnboarded = snap.hasOnboarded
            iCloudEnabled = snap.iCloudEnabled
            mealReminders = snap.mealReminders
        } else {
            entries = []
            recipes = []
            supplements = []
            foods = []
            goals = Goals()
            metrics = UserMetrics()
            units = .metric
            dietaryNotes = ""
            appleHealthConnected = false
            hasOnboarded = false
            iCloudEnabled = true
            mealReminders = MealReminders()
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(iCloudChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: kvStore)
        kvStore.synchronize()
    }

    // MARK: - Day helpers

    func isSelectedDateToday() -> Bool { Calendar.current.isDateInToday(selectedDate) }
    func goToPreviousDay() { selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate }
    func goToNextDay() {
        guard !isSelectedDateToday() else { return }
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }
    func goToToday() { selectedDate = Calendar.current.startOfDay(for: Date()) }

    // MARK: - Derived totals

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
    func deleteEntry(_ entry: FoodEntry) { entries.removeAll { $0.id == entry.id } }

    // MARK: - Food catalog

    /// Insert or update a food in the catalog and mark it just used.
    func recordUse(name: String, brand: String?, per100g: Nutrients, barcode: String?) {
        if let idx = foods.firstIndex(where: { $0.matches(name: name, brand: brand, barcode: barcode) }) {
            foods[idx].lastUsedAt = Date()
            foods[idx].per100g = per100g
        } else {
            foods.append(FoodItem(name: name, brand: brand, per100g: per100g,
                                  barcode: barcode, lastUsedAt: Date()))
        }
    }

    func toggleFavorite(name: String, brand: String?, per100g: Nutrients, barcode: String?) {
        if let idx = foods.firstIndex(where: { $0.matches(name: name, brand: brand, barcode: barcode) }) {
            foods[idx].isFavorite.toggle()
        } else {
            foods.append(FoodItem(name: name, brand: brand, per100g: per100g,
                                  isFavorite: true, barcode: barcode))
        }
    }

    func isFavorite(name: String, brand: String?, barcode: String?) -> Bool {
        foods.first(where: { $0.matches(name: name, brand: brand, barcode: barcode) })?.isFavorite ?? false
    }

    func addCustomFood(name: String, brand: String?, per100g: Nutrients) {
        foods.append(FoodItem(name: name, brand: brand, per100g: per100g, isCustom: true))
    }

    func deleteFood(_ item: FoodItem) { foods.removeAll { $0.id == item.id } }

    var favoriteFoods: [FoodItem] { foods.filter { $0.isFavorite }.sorted { $0.name < $1.name } }
    var recentFoods: [FoodItem] {
        foods.filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
    }
    var customFoods: [FoodItem] { foods.filter { $0.isCustom }.sorted { $0.name < $1.name } }

    // MARK: - Recipe mutations

    func addRecipe(_ recipe: Recipe) { recipes.append(recipe) }
    func updateRecipe(_ recipe: Recipe) {
        guard let idx = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[idx] = recipe
    }
    func deleteRecipe(_ recipe: Recipe) { recipes.removeAll { $0.id == recipe.id } }
    func deleteRecipes(at offsets: IndexSet) { recipes.remove(atOffsets: offsets) }

    func logRecipe(_ recipe: Recipe, servings: Double, to meal: MealType, on day: Date) {
        let base = recipe.effectiveNutrients
        let perServing = recipe.servings > 0 ? recipe.servings : 1
        let factor = servings / perServing
        let total = Nutrients(
            calories: base.calories * factor, protein: base.protein * factor,
            carbs: base.carbs * factor, fat: base.fat * factor)
        addEntry(FoodEntry(name: recipe.name, meal: meal, grams: 0, nutrients: total, date: day))
    }

    // MARK: - Supplement mutations

    func addSupplement(_ supplement: Supplement) { supplements.append(supplement) }
    func updateSupplement(_ supplement: Supplement) {
        guard let idx = supplements.firstIndex(where: { $0.id == supplement.id }) else { return }
        supplements[idx] = supplement
    }
    func deleteSupplements(at offsets: IndexSet) { supplements.remove(atOffsets: offsets) }
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

    // MARK: - Export

    /// Write a full JSON export to a temp file and return its URL.
    func exportFileURL() -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot()) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nutrimaxx-data.json")
        try? data.write(to: url)
        return url
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var entries: [FoodEntry]
        var recipes: [Recipe]
        var supplements: [Supplement]
        var foods: [FoodItem]
        var goals: Goals
        var metrics: UserMetrics
        var units: UnitSystem
        var dietaryNotes: String
        var appleHealthConnected: Bool
        var hasOnboarded: Bool
        var iCloudEnabled: Bool
        var mealReminders: MealReminders
        var savedAt: Date = Date()
    }

    private func snapshot() -> Snapshot {
        Snapshot(entries: entries, recipes: recipes, supplements: supplements, foods: foods,
                 goals: goals, metrics: metrics, units: units, dietaryNotes: dietaryNotes,
                 appleHealthConnected: appleHealthConnected, hasOnboarded: hasOnboarded,
                 iCloudEnabled: iCloudEnabled, mealReminders: mealReminders, savedAt: Date())
    }

    private func save() {
        guard !isApplyingRemote else { return }
        guard let data = try? JSONEncoder().encode(snapshot()) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
        if iCloudEnabled {
            kvStore.set(data, forKey: defaultsKey)
            kvStore.synchronize()
        }
    }

    private static func load() -> Snapshot? {
        guard let data = UserDefaults.standard.data(forKey: "nutrimaxx.state.v6"),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return nil }
        return snap
    }

    private static func loadFromICloud() -> Snapshot? {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: "nutrimaxx.state.v6"),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return nil }
        return snap
    }

    @objc private func iCloudChanged(_ note: Notification) {
        guard iCloudEnabled, let remote = Self.loadFromICloud() else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isApplyingRemote = true
            self.entries = remote.entries
            self.recipes = remote.recipes
            self.supplements = remote.supplements
            self.foods = remote.foods
            self.goals = remote.goals
            self.metrics = remote.metrics
            self.units = remote.units
            self.dietaryNotes = remote.dietaryNotes
            self.mealReminders = remote.mealReminders
            self.isApplyingRemote = false
        }
    }
}

private extension FoodItem {
    func matches(name: String, brand: String?, barcode: String?) -> Bool {
        if let barcode, let mine = self.barcode { return barcode == mine }
        return self.name.caseInsensitiveCompare(name) == .orderedSame
            && (self.brand ?? "") == (brand ?? "")
    }
}
