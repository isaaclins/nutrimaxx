import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
            RecipesView()
                .tabItem { Label("Recipes", systemImage: "book") }
            LogView()
                .tabItem { Label("Log", systemImage: "plus.circle") }
            SupplementsView()
                .tabItem { Label("Supplements", systemImage: "pills") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
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
