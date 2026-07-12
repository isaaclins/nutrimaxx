import SwiftUI

struct LogView: View {
    @EnvironmentObject var store: AppStore

    @State private var showAddFood = false
    @State private var addMeal: MealType = .breakfast
    @State private var showScanComingSoon = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(MealType.allCases) { meal in
                    Section(meal.title) {
                        let items = store.entries(for: meal)
                        if items.isEmpty {
                            Text("Nothing logged")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(items) { entry in
                                HStack {
                                    Text(entry.name)
                                    Spacer()
                                    Text("\(Format.kcal(entry.nutrients.calories)) kcal")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .onDelete { store.deleteEntries(for: meal, at: $0) }
                        }

                        Button {
                            addMeal = meal
                            showAddFood = true
                        } label: {
                            Label("Add food", systemImage: "plus")
                        }
                    }
                }
            }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        addMeal = .breakfast
                        showAddFood = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    Button {
                        showScanComingSoon = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $showAddFood) {
                AddFoodView(meal: addMeal).environmentObject(store)
            }
            .comingSoon($showScanComingSoon)
        }
    }
}
