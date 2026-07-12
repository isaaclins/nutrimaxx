import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var health: HealthManager

    var body: some View {
        NavigationStack {
            Form {
                integrations
                healthData
                bodyMetrics
                preferences
                reminders
                goals
                data
                about
            }
            .navigationTitle("Settings")
            .keyboardDoneToolbar()
        }
        .task {
            if store.appleHealthConnected { await health.requestAuthorization() }
        }
    }

    // MARK: - Integrations

    private var integrations: some View {
        Section("Integrations") {
            if store.appleHealthConnected {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health Connected")
                    Text("Syncs automatically").font(.caption).foregroundStyle(.secondary)
                }
                Button("Disconnect Apple Health", role: .destructive) {
                    store.appleHealthConnected = false
                }
            } else {
                Button("Connect Apple Health") {
                    store.appleHealthConnected = true
                    Task { await health.requestAuthorization() }
                }
            }
        }
    }

    private var healthData: some View {
        Section("Health Data") {
            LabeledContent("Latest Weight") {
                Text(health.latestWeightKg.map { Format.weight($0, units: store.units) } ?? "--")
            }
            LabeledContent("Active Energy Today") {
                Text(health.activeEnergyTodayKcal.map { "\(Format.kcal($0)) kcal" } ?? "--")
            }
            LabeledContent("Resting Energy Today") {
                Text(health.restingEnergyTodayKcal.map { "\(Format.kcal($0)) kcal" } ?? "--")
            }
            LabeledContent("Steps Today") {
                Text(health.stepsToday.map { String(Int($0)) } ?? "--")
            }
            LabeledContent("Water Today") {
                Text(health.waterTodayLiters.map { String(format: "%.2f L", $0) } ?? "--")
            }
            Button("Add 250 ml Water") { health.addWater(liters: 0.25) }
                .disabled(!store.appleHealthConnected)
        }
    }

    private var bodyMetrics: some View {
        Section("Body Metrics") {
            Picker("Sex", selection: $store.metrics.sex) {
                ForEach(BiologicalSex.allCases) { Text($0.rawValue).tag($0) }
            }
            DatePicker("Birthday", selection: $store.metrics.birthday,
                       in: ...Date(), displayedComponents: .date)
            LabeledContent("Age", value: "\(store.metrics.age) yr")
            metricField("Height", $store.metrics.heightCm, unit: "cm")
            metricField("Weight", $store.metrics.weightKg, unit: "kg")
            Picker("Activity", selection: $store.metrics.activity) {
                ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) }
            }
            LabeledContent("Maintenance", value: "\(Format.kcal(store.metrics.tdee)) kcal")
        }
    }

    private var preferences: some View {
        Section("Preferences") {
            Picker("Units", selection: $store.units) {
                ForEach(UnitSystem.allCases) { Text($0.rawValue).tag($0) }
            }
            TextField("Dietary Notes", text: $store.dietaryNotes, axis: .vertical)
                .lineLimit(1...4)
        }
    }

    private var reminders: some View {
        Section("Meal Reminders") {
            Toggle("Enable reminders", isOn: $store.mealReminders.enabled)
            if store.mealReminders.enabled {
                reminderRow("Breakfast", $store.mealReminders.breakfastEnabled, timeBinding(\.breakfastTime))
                reminderRow("Lunch", $store.mealReminders.lunchEnabled, timeBinding(\.lunchTime))
                reminderRow("Dinner", $store.mealReminders.dinnerEnabled, timeBinding(\.dinnerTime))
            }
        }
    }

    private var goals: some View {
        Section("Goals") {
            Picker("Goal", selection: $store.goals.type) {
                ForEach(GoalType.allCases) { Text($0.rawValue).tag($0) }
            }
            goalField("Calories", $store.goals.calories, unit: "kcal")
            goalField("Protein", $store.goals.protein, unit: "g")
            goalField("Carbs", $store.goals.carbs, unit: "g")
            goalField("Fat", $store.goals.fat, unit: "g")
            Button("Recalculate from metrics for \(store.goals.type.rawValue)") {
                var suggested = Goals.suggested(for: store.goals.type, metrics: store.metrics)
                suggested.type = store.goals.type
                store.goals = suggested
            }
        }
    }

    private var data: some View {
        Section {
            Toggle("iCloud Sync", isOn: $store.iCloudEnabled)
            if let url = store.exportFileURL() {
                ShareLink(item: url) {
                    Label("Download all my data", systemImage: "square.and.arrow.up")
                }
            }
        } header: {
            Text("Data")
        } footer: {
            Text("iCloud sync requires a paid Apple Developer account; until then data stays on this device. Use \u{201C}Download all my data\u{201D} to export a full backup anytime.")
        }
    }

    private var about: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0")
            Button("Replay Onboarding") { store.hasOnboarded = false }
        }
    }

    // MARK: - Helpers

    private func reminderRow(_ label: String, _ enabled: Binding<Bool>, _ time: Binding<Date>) -> some View {
        HStack {
            Toggle(label, isOn: enabled)
            if enabled.wrappedValue {
                DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
        }
    }

    /// Binding that maps a stored "HH:mm" string to a Date for the picker.
    private func timeBinding(_ keyPath: WritableKeyPath<MealReminders, String>) -> Binding<Date> {
        Binding(
            get: {
                let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
                return formatter.date(from: store.mealReminders[keyPath: keyPath]) ?? Date()
            },
            set: { newValue in
                let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
                store.mealReminders[keyPath: keyPath] = formatter.string(from: newValue)
            }
        )
    }

    private func metricField(_ label: String, _ value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: value, format: .number)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 120)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func goalField(_ label: String, _ value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: value, format: .number)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 120)
            Text(unit).foregroundStyle(.secondary)
        }
    }
}
