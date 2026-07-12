import Foundation

// MARK: - Nutrients

/// Per-serving nutrient values (already scaled to the amount logged).
struct Nutrients: Codable, Hashable {
    var calories: Double = 0   // kcal
    var protein: Double = 0    // g
    var carbs: Double = 0      // g
    var fat: Double = 0        // g

    static func + (lhs: Nutrients, rhs: Nutrients) -> Nutrients {
        Nutrients(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat
        )
    }

    /// Scale nutrients (given per 100 g) to a gram amount.
    func scaled(toGrams grams: Double) -> Nutrients {
        let factor = grams / 100.0
        return Nutrients(
            calories: calories * factor,
            protein: protein * factor,
            carbs: carbs * factor,
            fat: fat * factor
        )
    }
}

// MARK: - Meals & food entries

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snacks
    var id: String { rawValue }
    var title: String {
        switch self {
        case .breakfast: return "BREAKFAST"
        case .lunch: return "LUNCH"
        case .dinner: return "DINNER"
        case .snacks: return "SNACKS"
        }
    }
}

/// A single logged food item within a meal on a given day.
struct FoodEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var meal: MealType
    var grams: Double            // amount logged
    var nutrients: Nutrients     // already scaled to `grams`
    var date: Date = .init()
    /// Per-100g values this entry was logged from (OpenFoodFacts). Lets us
    /// re-scale nutrients when the amount is edited. Nil for manual entries.
    var basePer100g: Nutrients? = nil
}

// MARK: - Recipes

struct Recipe: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var servings: Double
    var nutrients: Nutrients   // total for the whole recipe

    var caloriesPerServing: Double {
        servings > 0 ? nutrients.calories / servings : nutrients.calories
    }
}

// MARK: - Supplements

struct Supplement: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var frequency: String   // e.g. "Daily"
    var time: String        // e.g. "08:00"
    /// Day-start dates on which this supplement was marked taken (the log/history).
    var takenDates: [Date] = []

    func isTaken(on day: Date) -> Bool {
        takenDates.contains { Calendar.current.isDate($0, inSameDayAs: day) }
    }

    var takenToday: Bool { isTaken(on: Date()) }

    /// Parsed hour/minute from the "HH:mm" time string, for notifications.
    var hourMinute: (hour: Int, minute: Int)? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }
}

// MARK: - Goals & preferences

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case buildMuscle = "Build Muscle"
    case loseFat = "Lose Fat"
    case maintain = "Maintain"
    var id: String { rawValue }
}

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case metric = "Metric"
    case imperial = "Imperial"
    var id: String { rawValue }
}

struct Goals: Codable, Hashable {
    var type: GoalType = .maintain
    var calories: Double = 2000
    var protein: Double = 150
    var carbs: Double = 200
    var fat: Double = 65

    /// Suggested targets for a goal type, optionally scaled to body weight.
    /// Protein is set per kg of bodyweight; the rest follows typical splits.
    static func suggested(for type: GoalType, weightKg: Double? = nil) -> Goals {
        let weight = weightKg ?? 75
        switch type {
        case .buildMuscle:
            let calories = weight * 38
            let protein = weight * 2.2
            let fat = (calories * 0.25) / 9
            let carbs = (calories - protein * 4 - fat * 9) / 4
            return Goals(type: type, calories: calories.rounded(), protein: protein.rounded(),
                         carbs: carbs.rounded(), fat: fat.rounded())
        case .loseFat:
            let calories = weight * 26
            let protein = weight * 2.2
            let fat = (calories * 0.30) / 9
            let carbs = (calories - protein * 4 - fat * 9) / 4
            return Goals(type: type, calories: calories.rounded(), protein: protein.rounded(),
                         carbs: carbs.rounded(), fat: fat.rounded())
        case .maintain:
            let calories = weight * 32
            let protein = weight * 1.8
            let fat = (calories * 0.28) / 9
            let carbs = (calories - protein * 4 - fat * 9) / 4
            return Goals(type: type, calories: calories.rounded(), protein: protein.rounded(),
                         carbs: carbs.rounded(), fat: fat.rounded())
        }
    }
}
