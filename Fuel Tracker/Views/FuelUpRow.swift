import SwiftUI

struct FuelUpRow: View {
    let fuelUp: FuelUp
    let distanceUnit: DistanceUnit
    let volumeUnit: VolumeUnit
    let efficiencyUnit: EfficiencyUnit
    let currencySymbol: String
    let efficiency: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(fuelUp.date, style: .date)
                    .font(.headline)
                Spacer()
                Text("\(currencySymbol)\(fuelUp.totalCost, specifier: "%.2f")")
                    .font(.headline)
            }

            HStack {
                Label(
                    "\(Int(UnitConversion.displayDistance(fuelUp.odometer, unit: distanceUnit))) \(distanceUnit.shortLabel)",
                    systemImage: "speedometer"
                )
                Spacer()
                Label(
                    String(
                        format: "%.2f %@",
                        UnitConversion.displayVolume(fuelUp.volume, unit: volumeUnit),
                        volumeUnit.shortLabel
                    ),
                    systemImage: "drop.fill"
                )
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let efficiency {
                Text("\(String(format: "%.1f", efficiency)) \(efficiencyUnit.shortLabel)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            }

            if !fuelUp.isFullTank {
                Text("Partial fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if !fuelUp.notes.isEmpty {
                Text(fuelUp.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
