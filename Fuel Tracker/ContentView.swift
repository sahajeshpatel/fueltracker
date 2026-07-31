import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var vehicles: [Vehicle]

    var body: some View {
        Group {
            if let vehicle = vehicles.first {
                MainTabView(vehicle: vehicle)
            } else {
                ProgressView()
                    .onAppear { createDefaultVehicleIfNeeded() }
            }
        }
    }

    private func createDefaultVehicleIfNeeded() {
        guard vehicles.isEmpty else { return }
        let vehicle = Vehicle(name: "My Car")
        modelContext.insert(vehicle)
        try? modelContext.save()
    }
}

struct MainTabView: View {
    let vehicle: Vehicle

    var body: some View {
        TabView {
            FuelLogListView(vehicle: vehicle)
                .tabItem { Label("Fuel Log", systemImage: "fuelpump.fill") }

            StatsView(vehicle: vehicle)
                .tabItem { Label("Stats", systemImage: "chart.xyaxis.line") }

            SettingsView(vehicle: vehicle)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Vehicle.self, FuelUp.self], inMemory: true)
}
