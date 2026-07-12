import SwiftUI
import Charts

/// Visual weekly statistics: calories per day, macro averages, weight trend,
/// supplement adherence, and logging streak.
struct StatsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var health: HealthManager

    @State private var weightSeries: [WeightPoint] = []

    private struct DayStat: Identifiable {
        let id = UUID()
        let date: Date
        let nutrients: Nutrients
        var label: String {
            let f = DateFormatter(); f.dateFormat = "EEE"
            return f.string(from: date)
        }
    }

    struct WeightPoint: Identifiable {
        let id = UUID()
        let date: Date
        let kg: Double
    }

    private var last7: [DayStat] {
        (0..<7).reversed().compactMap { offset in
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return DayStat(date: day, nutrients: store.consumed(on: day))
        }
    }

    private var avgCalories: Double {
        let vals = last7.map { $0.nutrients.calories }
        return vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
    }
    private var avgProtein: Double { average(\.protein) }
    private var avgCarbs: Double { average(\.carbs) }
    private var avgFat: Double { average(\.fat) }

    private func average(_ key: KeyPath<Nutrients, Double>) -> Double {
        let vals = last7.map { $0.nutrients[keyPath: key] }
        return vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
    }

    private var loggingStreak: Int {
        var streak = 0
        var day = Calendar.current.startOfDay(for: Date())
        while !store.entries(on: day).isEmpty {
            streak += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    private var supplementAdherence: Double {
        guard !store.supplements.isEmpty else { return 0 }
        var taken = 0, total = 0
        for offset in 0..<7 {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            for supp in store.supplements {
                total += 1
                if supp.isTaken(on: day) { taken += 1 }
            }
        }
        return total == 0 ? 0 : Double(taken) / Double(total)
    }

    var body: some View {
        List {
            Section("This Week") {
                statRow("Avg calories", "\(Format.kcal(avgCalories)) kcal")
                statRow("Avg protein", "\(Format.grams(avgProtein)) g")
                statRow("Avg carbs", "\(Format.grams(avgCarbs)) g")
                statRow("Avg fat", "\(Format.grams(avgFat)) g")
                statRow("Logging streak", "\(loggingStreak) day\(loggingStreak == 1 ? "" : "s")")
                if !store.supplements.isEmpty {
                    statRow("Supplement adherence", "\(Int((supplementAdherence * 100).rounded()))%")
                }
            }

            Section("Calories (last 7 days)") {
                Chart {
                    ForEach(last7) { stat in
                        BarMark(
                            x: .value("Day", stat.label),
                            y: .value("kcal", stat.nutrients.calories)
                        )
                        .foregroundStyle(.blue)
                    }
                    RuleMark(y: .value("Goal", store.goals.calories))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
                .frame(height: 200)
            }

            Section("Macros (avg, last 7 days)") {
                Chart {
                    BarMark(x: .value("Macro", "Protein"), y: .value("g", avgProtein))
                        .foregroundStyle(.purple)
                    BarMark(x: .value("Macro", "Carbs"), y: .value("g", avgCarbs))
                        .foregroundStyle(.blue)
                    BarMark(x: .value("Macro", "Fat"), y: .value("g", avgFat))
                        .foregroundStyle(.orange)
                }
                .frame(height: 180)
            }

            Section("Weight trend") {
                if weightSeries.isEmpty {
                    Text("No weight data in Apple Health.")
                        .foregroundStyle(.secondary)
                } else {
                    Chart(weightSeries) { point in
                        LineMark(x: .value("Date", point.date), y: .value("kg", point.kg))
                            .foregroundStyle(.green)
                        PointMark(x: .value("Date", point.date), y: .value("kg", point.kg))
                            .foregroundStyle(.green)
                    }
                    .frame(height: 200)
                }
            }
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let series = await health.weightSeries(days: 30)
            weightSeries = series.map { WeightPoint(date: $0.date, kg: $0.kg) }
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary) }
    }
}
