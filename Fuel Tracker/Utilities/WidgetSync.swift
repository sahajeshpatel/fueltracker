import Foundation
import WidgetKit

/// Shared contract between the app and the widget extension. The app writes a
/// small snapshot of the most recent efficiency figure into the App Group
/// container, and the widget reads these same keys.
///
/// Keep these identifiers in sync with the copy in the FuelWidget target.
enum WidgetSharedStore {
    static let appGroupID = "group.sahajesh.Fuel-Tracker"

    enum Key {
        static let efficiencyValue = "widget.efficiencyValue"
        static let efficiencyUnitLabel = "widget.efficiencyUnitLabel"
        static let vehicleName = "widget.vehicleName"
        static let date = "widget.date"
        static let hasData = "widget.hasData"
    }

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
}

enum WidgetSync {
    /// Recomputes the latest full-to-full efficiency figure for the vehicle in
    /// the user's chosen unit, writes it to the shared container, and asks
    /// WidgetKit to refresh all timelines.
    static func refresh(for vehicle: Vehicle) {
        guard let defaults = WidgetSharedStore.defaults else { return }

        let unitRaw = UserDefaults.standard.string(forKey: AppStorageKeys.efficiencyUnit)
        let unit = EfficiencyUnit(rawValue: unitRaw ?? "") ?? .mpgUK

        let records = EfficiencyCalculator.records(for: vehicle.fuelUps)

        if let latest = records.max(by: { $0.date < $1.date }) {
            let value = UnitConversion.efficiency(
                distanceMiles: latest.distanceMiles,
                volumeLiters: latest.volumeLiters,
                unit: unit
            )
            defaults.set(value, forKey: WidgetSharedStore.Key.efficiencyValue)
            defaults.set(unit.shortLabel, forKey: WidgetSharedStore.Key.efficiencyUnitLabel)
            defaults.set(vehicle.name, forKey: WidgetSharedStore.Key.vehicleName)
            defaults.set(latest.date.timeIntervalSince1970, forKey: WidgetSharedStore.Key.date)
            defaults.set(true, forKey: WidgetSharedStore.Key.hasData)
        } else {
            defaults.set(false, forKey: WidgetSharedStore.Key.hasData)
            defaults.set(vehicle.name, forKey: WidgetSharedStore.Key.vehicleName)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
