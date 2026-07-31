import SwiftUI
import SwiftData

/// Landing screen shown when the app opens. Surfaces the headline numbers:
/// total spent on fuel, the most recent efficiency figure, and the odometer
/// reading of the last fill-up.
struct DashboardView: View {
    let vehicle: Vehicle

    @AppStorage(AppStorageKeys.distanceUnit) private var distanceUnitRaw = DistanceUnit.miles.rawValue
    @AppStorage(AppStorageKeys.volumeUnit) private var volumeUnitRaw = VolumeUnit.liters.rawValue
    @AppStorage(AppStorageKeys.efficiencyUnit) private var efficiencyUnitRaw = EfficiencyUnit.mpgUK.rawValue
    @AppStorage(AppStorageKeys.currencySymbol) private var currencySymbol = "£"

    private var distanceUnit: DistanceUnit { DistanceUnit(rawValue: distanceUnitRaw) ?? .miles }
    private var efficiencyUnit: EfficiencyUnit { EfficiencyUnit(rawValue: efficiencyUnitRaw) ?? .mpgUK }

    private var totalSpent: Double {
        vehicle.fuelUps.reduce(0) { $0 + $1.totalCost }
    }

    /// The most recent full-to-full efficiency figure, in the user's unit.
    private var currentEfficiency: Double? {
        let records = EfficiencyCalculator.records(for: vehicle.fuelUps)
        guard let latest = records.max(by: { $0.date < $1.date }) else { return nil }
        return UnitConversion.efficiency(
            distanceMiles: latest.distanceMiles,
            volumeLiters: latest.volumeLiters,
            unit: efficiencyUnit
        )
    }

    private var lastFuelUp: FuelUp? {
        vehicle.fuelUps.max { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if vehicle.fuelUps.isEmpty {
                    ContentUnavailableView(
                        "No Data Yet",
                        systemImage: "gauge.medium",
                        description: Text("Log a fuel-up to see your dashboard.")
                    )
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 16) {
                        StatCard(
                            title: "Total Spent on Fuel",
                            value: "\(currencySymbol)\(String(format: "%.2f", totalSpent))"
                        )

                        HStack(spacing: 16) {
                            StatCard(
                                title: "Current \(efficiencyUnit.shortLabel)",
                                value: currentEfficiency.map { String(format: "%.1f", $0) } ?? "—"
                            )
                            StatCard(
                                title: lastFillUpTitle,
                                value: lastFillUpValue
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Dashboard")
            .onAppear { WidgetSync.refresh(for: vehicle) }
        }
    }

    private var lastFillUpTitle: String {
        guard let lastFuelUp else { return "Last Fill-Up" }
        return "Last Fill-Up · \(lastFuelUp.date.formatted(.dateTime.day().month(.abbreviated)))"
    }

    private var lastFillUpValue: String {
        guard let lastFuelUp else { return "—" }
        let miles = UnitConversion.displayDistance(lastFuelUp.odometer, unit: distanceUnit)
        return "\(Int(miles).formatted()) \(distanceUnit.shortLabel)"
    }
}
