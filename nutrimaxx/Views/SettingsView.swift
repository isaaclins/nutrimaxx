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
                goals
                about
            }
            .navigationTitle("Settings")
        }
        .task {
            if store.appleHealthConnected {
                await health.requestAuthorization()
            }
        }
    }

    private var integrations: some View {
        Section("Integrations") {
            if store.appleHealthConnected {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Health Connected")
                    Text("Syncs automatically")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        }
    }

    private var bodyMetrics: some View {
        Section("Body Metrics") {
            Picker("Sex", selection: $store.metrics.sex) {
                ForEach(BiologicalSex.allCases) { Text($0.rawValue).tag($0) }
            }
            Stepper("Age: \(store.metrics.age) yr", value: $store.metrics.age, in: 13...100)
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

    private var about: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0")
            Button("Replay Onboarding") { store.hasOnboarded = false }
        }
    }

    private func metricField(_ label: String, _ value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func goalField(_ label: String, _ value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
            Text(unit).foregroundStyle(.secondary)
        }
    }
}
