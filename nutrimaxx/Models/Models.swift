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
    var takenToday: Bool = false
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
    var type: GoalType = .buildMuscle
    var calories: Double = 2927
    var protein: Double = 256.2
    var carbs: Double = 256.2
    var fat: Double = 97.6
}
