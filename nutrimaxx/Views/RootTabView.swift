import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var store: AppStore
    @State private var selection = UserDefaults.standard.integer(forKey: "debugTab")

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }.tag(0)
            RecipesView()
                .tabItem { Label("Recipes", systemImage: "book") }.tag(1)
            LogView()
                .tabItem { Label("Log", systemImage: "plus.circle") }.tag(2)
            SupplementsView()
                .tabItem { Label("Supplements", systemImage: "pills") }.tag(3)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }.tag(4)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !store.hasOnboarded },
            set: { _ in }
        )) {
            OnboardingView()
                .environmentObject(store)
        }
    }
}
