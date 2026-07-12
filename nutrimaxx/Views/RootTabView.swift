import SwiftUI

struct RootTabView: View {
    // Optional initial tab via launch argument, e.g. `-startTab 4`. Defaults to Dashboard.
    @State private var selection: Int = {
        if let raw = UserDefaults.standard.string(forKey: "startTab"), let value = Int(raw) {
            return value
        }
        return 0
    }()

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                .tag(0)
            RecipesView()
                .tabItem { Label("Recipes", systemImage: "book") }
                .tag(1)
            LogView()
                .tabItem { Label("Log", systemImage: "plus.circle") }
                .tag(2)
            SupplementsView()
                .tabItem { Label("Supplements", systemImage: "pills") }
                .tag(3)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
        }
    }
}
