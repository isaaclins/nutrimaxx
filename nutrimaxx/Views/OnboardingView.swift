import SwiftUI

/// First-launch onboarding: pick a goal, review auto-suggested targets (editable),
/// then optionally enable supplement reminders.
struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var health: HealthManager

    @State private var step = 0
    @State private var goalType: GoalType = .maintain
    @State private var goals = Goals()

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 0: welcome
                case 1: goalStep
                case 2: targetsStep
                default: notificationsStep
                }
            }
            .padding()
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("nutrimaxx").font(.largeTitle.bold())
            Text("Track your food, recipes, supplements and macros. Let's set up your goals.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Get Started") { step = 1 }
                .buttonStyle(.borderedProminent)
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What's your goal?").font(.title2.bold())
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
                goals = Goals.suggested(for: goalType, weightKg: health.latestWeightKg)
                step = 2
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }

    private var targetsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your daily targets").font(.title2.bold())
            Text("Suggested for \(goalType.rawValue). Adjust anything you like.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Form {
                targetField("Calories", $goals.calories, unit: "kcal")
                targetField("Protein", $goals.protein, unit: "g")
                targetField("Carbs", $goals.carbs, unit: "g")
                targetField("Fat", $goals.fat, unit: "g")
            }
            .frame(maxHeight: 300)

            Button("Continue") { step = 3 }
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

    private func finish() {
        goals.type = goalType
        store.goals = goals
        store.hasOnboarded = true
    }
}
