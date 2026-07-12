import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var health: HealthManager

    var body: some View {
        NavigationStack {
            Form {
                integrations
                healthData
                preferences
                goals
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
                Text(health.latestWeightKg.map { "\(Format.grams($0)) kg" } ?? "--")
            }
            LabeledContent("Active Energy Today") {
                Text(health.activeEnergyTodayKcal.map { "\(Format.kcal($0)) kcal" } ?? "--")
            }
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
