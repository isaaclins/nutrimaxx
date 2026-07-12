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
        }
    }
}
