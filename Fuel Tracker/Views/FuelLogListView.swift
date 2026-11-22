import SwiftUI
import SwiftData

struct FuelLogListView: View {
    let vehicle: Vehicle
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSheet = false
    @State private var editingFuelUp: FuelUp?

    @AppStorage(AppStorageKeys.distanceUnit) private var distanceUnitRaw = DistanceUnit.miles.rawValue
    @AppStorage(AppStorageKeys.volumeUnit) private var volumeUnitRaw = VolumeUnit.liters.rawValue
    @AppStorage(AppStorageKeys.efficiencyUnit) private var efficiencyUnitRaw = EfficiencyUnit.mpgUK.rawValue
    @AppStorage(AppStorageKeys.currencySymbol) private var currencySymbol = "£"

    private var distanceUnit: DistanceUnit { DistanceUnit(rawValue: distanceUnitRaw) ?? .miles }
    private var volumeUnit: VolumeUnit { VolumeUnit(rawValue: volumeUnitRaw) ?? .liters }
    private var efficiencyUnit: EfficiencyUnit { EfficiencyUnit(rawValue: efficiencyUnitRaw) ?? .mpgUK }

    private var sortedFuelUps: [FuelUp] {
        (vehicle.fuelUps ?? []).sorted { $0.date > $1.date }
    }

    private var efficiencyByFuelUpID: [PersistentIdentifier: Double] {
        var map: [PersistentIdentifier: Double] = [:]
        for record in EfficiencyCalculator.records(for: vehicle.fuelUps ?? []) {
            map[record.fuelUpID] = UnitConversion.efficiency(
                distanceMiles: record.distanceMiles,
                volumeLiters: record.volumeLiters,
                unit: efficiencyUnit
            )
        }
        return map
    }

    var body: some View {
        NavigationStack {
            List {
                if sortedFuelUps.isEmpty {
                    ContentUnavailableView(
                        "No Fuel-Ups Yet",
                        systemImage: "fuelpump",
                        description: Text("Tap + to log your first fill-up.")
                    )
                } else {
                    ForEach(sortedFuelUps) { fuelUp in
                        Button {
                            editingFuelUp = fuelUp
                        } label: {
                            FuelUpRow(
                                fuelUp: fuelUp,
                                distanceUnit: distanceUnit,
                                volumeUnit: volumeUnit,
                                efficiencyUnit: efficiencyUnit,
                                currencySymbol: currencySymbol,
                                efficiency: efficiencyByFuelUpID[fuelUp.id]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteFuelUps)
                }
            }
            .navigationTitle(vehicle.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddFuelUpView(vehicle: vehicle)
            }
            .sheet(item: $editingFuelUp) { fuelUp in
                AddFuelUpView(vehicle: vehicle, fuelUp: fuelUp)
            }
            .onAppear { WidgetSync.refresh(for: vehicle) }
        }
    }

    private func deleteFuelUps(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedFuelUps[index])
        }
        try? modelContext.save()
        WidgetSync.refresh(for: vehicle)
    }
}
