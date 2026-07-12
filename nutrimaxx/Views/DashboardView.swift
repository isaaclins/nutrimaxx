import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(greeting())
                        .font(.largeTitle.bold())

                    DayNavigator()

                    // Calories consumed
                    VStack(spacing: 4) {
                        Text(Format.grouped(store.consumed.calories))
                            .font(.system(size: 48, weight: .bold))
                        Text("kcal consumed")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)

                    macros

                    supplementsToday
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var macros: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macronutrients").font(.headline)
            macroRow("Protein", store.consumed.protein, store.goals.protein)
            macroRow("Carbs", store.consumed.carbs, store.goals.carbs)
            macroRow("Fat", store.consumed.fat, store.goals.fat)

            if store.consumed.fat > store.goals.fat {
                Text("Over by \(Format.grams(store.consumed.fat - store.goals.fat)) g")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.3)))
    }

    private func macroRow(_ name: String, _ value: Double, _ goal: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                Spacer()
                Text("\(Format.grams(value)) g / \(Format.grams(goal)) g")
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(value / max(goal, 1), 1))
        }
    }

    private var supplementsToday: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supplements Today").font(.headline)
            if store.supplements.isEmpty {
                Text("No supplements").foregroundStyle(.secondary)
            } else {
                ForEach(store.supplements) { supplement in
                    HStack {
                        Button {
                            store.toggleSupplement(supplement)
                        } label: {
                            Image(systemName: supplement.takenToday ? "largecircle.fill.circle" : "circle")
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading) {
                            Text(supplement.name)
                            Text(supplement.time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.3)))
    }
}

/// Shared previous/next-day header used by Dashboard and Log.
struct DayNavigator: View {
    @EnvironmentObject var store: AppStore

    private var label: String {
        if store.isSelectedDateToday() { return "Today" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: store.selectedDate)
    }

    var body: some View {
        HStack {
            Button { store.goToPreviousDay() } label: { Image(systemName: "chevron.left") }
            Spacer()
            Button { store.goToToday() } label: { Text(label).font(.subheadline.bold()) }
                .buttonStyle(.plain)
            Spacer()
            Button { store.goToNextDay() } label: { Image(systemName: "chevron.right") }
                .disabled(store.isSelectedDateToday())
        }
        .frame(maxWidth: .infinity)
    }
}
