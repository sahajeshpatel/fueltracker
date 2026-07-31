import Foundation
import SwiftData

@Model
final class FuelUp {
    var date: Date

    /// Always stored in miles, regardless of the user's display unit.
    var odometer: Double

    /// Always stored in liters, regardless of the user's display unit.
    var volume: Double

    /// Total amount paid, in whatever currency the user has set.
    var totalCost: Double

    /// Whether this fill-up topped the tank all the way up. Only full-to-full
    /// intervals are used to calculate efficiency, since partial fills make
    /// distance/fuel-used figures unreliable.
    var isFullTank: Bool

    var notes: String

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
