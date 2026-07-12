import SwiftUI

/// First-launch onboarding: enter body metrics, pick a goal, review the
/// computed targets (editable), then optionally enable supplement reminders.
struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var health: HealthManager

    @State private var step = 0
    @State private var metrics = UserMetrics()
    @State private var goalType: GoalType = .maintain
    @State private var goals = Goals()

    // Text fields for numeric metric entry.
    @State private var heightText = "175"
    @State private var weightText = "75"

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 0: welcome
                case 1: metricsStep
                case 2: goalStep
                case 3: targetsStep
                default: notificationsStep
                }
            }
            .padding()
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
        }
    }

    private var title: String {
        switch step {
        case 0: return "Welcome"
        case 1: return "About You"
        case 2: return "Your Goal"
        case 3: return "Your Targets"
        default: return "Reminders"
        }
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("nutrimaxx").font(.largeTitle.bold())
            Text("Track your food, recipes, supplements and macros. First, a few details so we can estimate your targets.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Get Started") {
                if let weight = health.latestWeightKg {
                    weightText = Format.grams(weight)
                }
                step = 1
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var metricsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your metrics").font(.title2.bold())
            Text("Used to estimate your daily calories and macros.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Form {
                Picker("Sex", selection: $metrics.sex) {
                    ForEach(BiologicalSex.allCases) { Text($0.rawValue).tag($0) }
                }
                DatePicker("Birthday", selection: $metrics.birthday,
                           in: ...Date(), displayedComponents: .date)
                numberRow("Height", $heightText, unit: "cm")
                numberRow("Weight", $weightText, unit: "kg")
                Picker("Activity", selection: $metrics.activity) {
                    ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            .scrollContentBackground(.hidden)
            .frame(maxHeight: 380)

            Button("Continue") {
                commitMetrics()
                step = 2
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What's your goal?").font(.title2.bold())
            Text("Estimated maintenance: \(Format.kcal(metrics.tdee)) kcal/day")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(GoalType.allCases) { type in
                Button {
                    goalType = type
                } label: {
                    HStack {
                        Text(type.rawValue)
                        Spacer()
                        Image(systemName: goalType == type ? "largecircle.fill.circle" : "circle")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary.opacity(0.3)))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button("Continue") {
                goals = Goals.suggested(for: goalType, metrics: metrics)
                step = 3
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }

    private var targetsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your daily targets").font(.title2.bold())
            Text("Calculated for \(goalType.rawValue) from your metrics. Adjust anything you like.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Form {
                targetField("Calories", $goals.calories, unit: "kcal")
                targetField("Protein", $goals.protein, unit: "g")
                targetField("Carbs", $goals.carbs, unit: "g")
                targetField("Fat", $goals.fat, unit: "g")
            }
            .scrollContentBackground(.hidden)
            .frame(maxHeight: 300)

            Button("Continue") { step = 4 }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
    }

    private var notificationsStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "bell.badge").font(.system(size: 48))
            Text("Supplement reminders").font(.title2.bold())
            Text("Get a daily notification when it's time to take a supplement. You can change this anytime in system Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Enable Notifications") {
                Task {
                    await NotificationManager.shared.requestAuthorization()
                    finish()
                }
            }
            .buttonStyle(.borderedProminent)
            Button("Not Now") { finish() }
        }
    }

    // MARK: - Helpers

    private func numberRow(_ label: String, _ text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func targetField(_ label: String, _ value: Binding<Double>, unit: String) -> some View {
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

    private func commitMetrics() {
        metrics.heightCm = Double(heightText) ?? metrics.heightCm
        metrics.weightKg = Double(weightText) ?? metrics.weightKg
    }

    private func finish() {
        goals.type = goalType
        store.metrics = metrics
        store.goals = goals
        store.hasOnboarded = true
    }
}
