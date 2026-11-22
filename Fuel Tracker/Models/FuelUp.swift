import Foundation
import SwiftData

@Model
final class FuelUp {
    // CloudKit sync requires every attribute to have a default value and every
    // relationship to be optional, so defaults are declared inline.
    var date: Date = Date()

    /// Always stored in miles, regardless of the user's display unit.
    var odometer: Double = 0

    /// Always stored in liters, regardless of the user's display unit.
    var volume: Double = 0

    /// Total amount paid, in whatever currency the user has set.
    var totalCost: Double = 0

    /// Whether this fill-up topped the tank all the way up. Only full-to-full
    /// intervals are used to calculate efficiency, since partial fills make
    /// distance/fuel-used figures unreliable.
    var isFullTank: Bool = true

    var notes: String = ""

    var vehicle: Vehicle?

    init(
        date: Date = Date(),
        odometer: Double,
        volume: Double,
        totalCost: Double,
        isFullTank: Bool = true,
        notes: String = ""
    ) {
        self.date = date
        self.odometer = odometer
        self.volume = volume
        self.totalCost = totalCost
        self.isFullTank = isFullTank
        self.notes = notes
    }

    var pricePerUnit: Double {
        guard volume > 0 else { return 0 }
        return totalCost / volume
    }
}
