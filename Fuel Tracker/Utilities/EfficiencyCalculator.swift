import Foundation
import SwiftData

struct EfficiencyRecord {
    let fuelUpID: PersistentIdentifier
    let date: Date
    let distanceMiles: Double
    let volumeLiters: Double
}

enum EfficiencyCalculator {
    /// Calculates efficiency between consecutive full-tank fill-ups.
    ///
    /// Partial fills contribute their fuel volume to the total but don't get
    /// their own efficiency figure, since only a full-to-full interval gives
    /// a trustworthy distance/fuel-used reading. This mirrors how Fuelly and
    /// most other fuel trackers calculate MPG.
    static func records(for fuelUps: [FuelUp]) -> [EfficiencyRecord] {
        let sorted = fuelUps.sorted { $0.odometer < $1.odometer }
        var results: [EfficiencyRecord] = []
        var lastFullIndex: Int?

        for (index, fillUp) in sorted.enumerated() where fillUp.isFullTank {
            defer { lastFullIndex = index }

            guard let lastIndex = lastFullIndex else { continue }

            let previousFull = sorted[lastIndex]
            let distance = fillUp.odometer - previousFull.odometer
            let volumeUsed = sorted[(lastIndex + 1)...index].reduce(0) { $0 + $1.volume }

            guard distance > 0, volumeUsed > 0 else { continue }

            results.append(
                EfficiencyRecord(
                    fuelUpID: fillUp.id,
                    date: fillUp.date,
                    distanceMiles: distance,
                    volumeLiters: volumeUsed
                )
            )
        }

        return results
    }
}
