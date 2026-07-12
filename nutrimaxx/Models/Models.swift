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

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    var id: String { rawValue }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary = "Sedentary"
    case light = "Lightly Active"
    case moderate = "Moderately Active"
    case active = "Active"
    case veryActive = "Very Active"
    var id: String { rawValue }

    /// TDEE multiplier applied to BMR.
    var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    var subtitle: String {
        switch self {
        case .sedentary: return "Little or no exercise"
        case .light: return "Exercise 1-3 days/week"
        case .moderate: return "Exercise 3-5 days/week"
        case .active: return "Exercise 6-7 days/week"
        case .veryActive: return "Hard exercise or physical job"
        }
    }
}

/// Body metrics used to estimate calorie and macro targets.
struct UserMetrics: Codable, Hashable {
    var birthday: Date = UserMetrics.defaultBirthday
    var sex: BiologicalSex = .male
    var heightCm: Double = 175
    var weightKg: Double = 75
    var activity: ActivityLevel = .moderate

    /// Default birthday: 30 years ago from today.
    static var defaultBirthday: Date {
        Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    }

    /// Age in whole years, derived from the birthday so it stays current.
    var age: Int {
        Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
    }

    /// Basal metabolic rate via the Mifflin-St Jeor equation.
    var bmr: Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return base + (sex == .male ? 5 : -161)
    }

    /// Total daily energy expenditure (maintenance calories).
    var tdee: Double { bmr * activity.factor }
}

struct Goals: Codable, Hashable {
    var type: GoalType = .maintain
    var calories: Double = 2000
    var protein: Double = 150
    var carbs: Double = 200
    var fat: Double = 65

    /// Suggested targets computed from body metrics (TDEE) and the goal type.
    /// Calories adjust TDEE up/down; protein scales with bodyweight; fat is a
    /// share of calories; carbs fill the remainder.
    static func suggested(for type: GoalType, metrics: UserMetrics) -> Goals {
        let tdee = metrics.tdee
        let weight = metrics.weightKg

        let calories: Double
        let proteinPerKg: Double
        let fatShare: Double
        switch type {
        case .buildMuscle:
            calories = tdee * 1.10
            proteinPerKg = 2.2
            fatShare = 0.25
        case .loseFat:
            calories = tdee * 0.80
            proteinPerKg = 2.2
            fatShare = 0.30
        case .maintain:
            calories = tdee
            proteinPerKg = 1.8
            fatShare = 0.28
        }

        let protein = weight * proteinPerKg
        let fat = (calories * fatShare) / 9
        let carbs = max((calories - protein * 4 - fat * 9) / 4, 0)

        return Goals(type: type, calories: calories.rounded(), protein: protein.rounded(),
                     carbs: carbs.rounded(), fat: fat.rounded())
    }
}
