import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var health: HealthManager

    private var activeEnergy: Double {
        store.isSelectedDateToday() ? (health.activeEnergyTodayKcal ?? 0) : 0
    }
    private var budget: Double { store.goals.calories + activeEnergy }
    private var caloriesRemaining: Double { budget - store.consumed.calories }
    private var ringProgress: Double { budget > 0 ? store.consumed.calories / budget : 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(greeting())
                        .font(.largeTitle.bold())

                    DayNavigator()

                    ring

                    macros

                    supplementsToday
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { StatsView() } label: { Image(systemName: "chart.bar") }
                }
            }
        }
    }

    // MARK: - Calorie ring

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 20)
            Circle()
                .trim(from: 0, to: min(ringProgress, 1))
                .stroke(ringProgress > 1 ? Color.red : Color.blue,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: ringProgress)

            VStack(spacing: 2) {
                Text(Format.grouped(store.consumed.calories))
                    .font(.system(size: 44, weight: .bold))
                    .contentTransition(.numericText())
                Text("kcal consumed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(caloriesRemaining >= 0
                     ? "\(Format.kcal(caloriesRemaining)) left"
                     : "\(Format.kcal(-caloriesRemaining)) over")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(caloriesRemaining >= 0 ? Color.blue : Color.red)
                    .padding(.top, 2)
            }
        }
        .frame(width: 240, height: 240)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            if activeEnergy > 0 {
                Text("Goal \(Format.kcal(store.goals.calories)) + \(Format.kcal(activeEnergy)) active")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Macros

    private var macros: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Macronutrients").font(.headline)
            MacroBar(name: "Protein", value: store.consumed.protein, goal: store.goals.protein, color: .purple)
            MacroBar(name: "Carbs", value: store.consumed.carbs, goal: store.goals.carbs, color: .blue)
            MacroBar(name: "Fat", value: store.consumed.fat, goal: store.goals.fat, color: .orange)
        }
        .cardStyle()
    }

    // MARK: - Supplements

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
                            Image(systemName: supplement.takenToday ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(supplement.takenToday ? Color.green : Color.secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading) {
                            Text(supplement.name)
                            Text(supplement.time).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .cardStyle()
    }
}

/// A labelled macro progress bar with a coloured capsule fill.
struct MacroBar: View {
    let name: String
    let value: Double
    let goal: Double
    let color: Color

    private var fraction: Double { goal > 0 ? min(value / goal, 1) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                Spacer()
                Text("\(Format.grams(value)) / \(Format.grams(goal)) g")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color)
                        .frame(width: max(geo.size.width * fraction, value > 0 ? 8 : 0))
                }
            }
            .frame(height: 8)
            if value > goal, goal > 0 {
                Text("Over by \(Format.grams(value - goal)) g")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }
}

/// Card container: padded rounded rectangle on the secondary system background.
private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}

/// Shared day header used by Dashboard and Log: step buttons plus a date picker
/// to jump to any past day. Works inside List rows (uses borderless buttons).
struct DayNavigator: View {
    @EnvironmentObject var store: AppStore
    @State private var showPicker = false

    private var label: String {
        if store.isSelectedDateToday() { return "Today" }
        if Calendar.current.isDateInYesterday(store.selectedDate) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: store.selectedDate)
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { store.selectedDate },
            set: { store.selectedDate = Calendar.current.startOfDay(for: $0) }
        )
    }

    var body: some View {
        HStack {
            Button { store.goToPreviousDay() } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)

            Spacer()

            Button { showPicker = true } label: {
                HStack(spacing: 6) {
                    Text(label).font(.subheadline.bold())
                    Image(systemName: "calendar").font(.caption)
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showPicker) {
                DatePicker("Select day", selection: dateBinding, in: ...Date(),
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .frame(minWidth: 300, minHeight: 320)
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }

            Spacer()

            Button { store.goToNextDay() } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .disabled(store.isSelectedDateToday())
        }
        .frame(maxWidth: .infinity)
    }
}
