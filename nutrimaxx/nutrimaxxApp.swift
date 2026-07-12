import SwiftUI

@main
struct nutrimaxxApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var health = HealthManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(health)
                .preferredColorScheme(.dark)
                .task {
                    // Keep reminders in sync on every launch.
                    NotificationManager.shared.reschedule(for: store.supplements)
                    NotificationManager.shared.scheduleMealReminders(store.mealReminders)
                }
        }
    }
}
