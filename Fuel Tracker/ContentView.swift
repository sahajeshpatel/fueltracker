import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    /// Prefers a vehicle that has fuel-ups, so a placeholder created on a new
    /// device doesn't hide the log that arrives from iCloud.
    private var currentVehicle: Vehicle? {
        vehicles.first { !($0.fuelUps ?? []).isEmpty } ?? vehicles.first
    }

    var body: some View {
        Group {
            if let vehicle = currentVehicle {
                MainTabView(vehicle: vehicle)
                    .id(vehicle.persistentModelID)
            } else {
                ProgressView()
                    .onAppear { createDefaultVehicleIfNeeded() }
            }
        }
        .onChange(of: vehicles.count) { removeEmptyDuplicateVehicles() }
    }

    private func createDefaultVehicleIfNeeded() {
        guard vehicles.isEmpty else { return }
        let vehicle = Vehicle(name: "My Car")
        modelContext.insert(vehicle)
        try? modelContext.save()
    }

    /// When iCloud sync brings in a vehicle from another device, delete any
    /// other vehicles that have no fuel-ups. These are placeholders created
    /// on first launch before the synced data arrived.
    private func removeEmptyDuplicateVehicles() {
        guard vehicles.count > 1, let keep = currentVehicle else { return }
        let emptyDuplicates = vehicles.filter { $0 !== keep && ($0.fuelUps ?? []).isEmpty }
        guard !emptyDuplicates.isEmpty else { return }
        emptyDuplicates.forEach(modelContext.delete)
        try? modelContext.save()
    }
}

struct MainTabView: View {
    let vehicle: Vehicle

    var body: some View {
        TabView {
            DashboardView(vehicle: vehicle)
                .tabItem { Label("Dashboard", systemImage: "gauge.medium") }

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
