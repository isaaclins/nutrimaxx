import SwiftUI

struct RootTabView: View {
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
    }
}
