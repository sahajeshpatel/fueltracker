import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    let vehicle: Vehicle

    @AppStorage(AppStorageKeys.distanceUnit) private var distanceUnitRaw = DistanceUnit.miles.rawValue
    @AppStorage(AppStorageKeys.volumeUnit) private var volumeUnitRaw = VolumeUnit.liters.rawValue
    @AppStorage(AppStorageKeys.efficiencyUnit) private var efficiencyUnitRaw = EfficiencyUnit.mpgUK.rawValue
    @AppStorage(AppStorageKeys.currencySymbol) private var currencySymbol = "£"

    private var distanceUnit: DistanceUnit { DistanceUnit(rawValue: distanceUnitRaw) ?? .miles }
    private var volumeUnit: VolumeUnit { VolumeUnit(rawValue: volumeUnitRaw) ?? .liters }
    private var efficiencyUnit: EfficiencyUnit { EfficiencyUnit(rawValue: efficiencyUnitRaw) ?? .mpgUK }

    private var efficiencyChartPoints: [ChartPoint] {
        EfficiencyCalculator.records(for: vehicle.fuelUps ?? []).map { record in
            ChartPoint(
                date: record.date,
                value: UnitConversion.efficiency(
                    distanceMiles: record.distanceMiles,
                    volumeLiters: record.volumeLiters,
                    unit: efficiencyUnit
                )
            )
        }
    }

    private var priceTrendPoints: [ChartPoint] {
        (vehicle.fuelUps ?? []).sorted { $0.date < $1.date }
            .map { fuelUp in
                let displayVolume = UnitConversion.displayVolume(fuelUp.volume, unit: volumeUnit)
                let price = displayVolume > 0 ? fuelUp.totalCost / displayVolume : 0
                return ChartPoint(date: fuelUp.date, value: price)
            }
    }

    private var averageEfficiency: Double {
        let points = efficiencyChartPoints
        guard !points.isEmpty else { return 0 }
        return points.map(\.value).reduce(0, +) / Double(points.count)
    }

    private var totalSpent: Double {
        (vehicle.fuelUps ?? []).reduce(0) { $0 + $1.totalCost }
    }

    private var totalDistance: Double {
        let sorted = (vehicle.fuelUps ?? []).sorted { $0.odometer < $1.odometer }
        guard let first = sorted.first, let last = sorted.last, sorted.count > 1 else { return 0 }
        return UnitConversion.displayDistance(last.odometer - first.odometer, unit: distanceUnit)
    }

    private var costPerDistance: Double {
        guard totalDistance > 0 else { return 0 }
        return totalSpent / totalDistance
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    summaryCards

                    if !efficiencyChartPoints.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Efficiency Over Time")
                                .font(.headline)
                            Chart(efficiencyChartPoints) { point in
                                LineMark(x: .value("Date", point.date), y: .value("Efficiency", point.value))
                                    .interpolationMethod(.catmullRom)
                                PointMark(x: .value("Date", point.date), y: .value("Efficiency", point.value))
                            }
                            .frame(height: 200)
                        }
                        .padding(.horizontal)
                    }

                    if priceTrendPoints.count > 1 {
                        VStack(alignment: .leading) {
                            Text("Fuel Price Trend")
                                .font(.headline)
                            Chart(priceTrendPoints) { point in
                                LineMark(x: .value("Date", point.date), y: .value("Price", point.value))
                                    .foregroundStyle(.orange)
                            }
                            .frame(height: 200)
                        }
                        .padding(.horizontal)
                    }

                    if efficiencyChartPoints.isEmpty && priceTrendPoints.count <= 1 {
                        ContentUnavailableView(
                            "Not Enough Data",
                            systemImage: "chart.xyaxis.line",
                            description: Text("Log at least two full fill-ups to see stats.")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Stats")
        }
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Avg Efficiency",
                value: averageEfficiency > 0
                    ? String(format: "%.1f %@", averageEfficiency, efficiencyUnit.shortLabel)
                    : "—"
            )
            StatCard(
                title: "Total Spent",
                value: "\(currencySymbol)\(String(format: "%.2f", totalSpent))"
            )
            StatCard(
                title: "Total Distance",
                value: totalDistance > 0 ? "\(Int(totalDistance)) \(distanceUnit.shortLabel)" : "—"
            )
            StatCard(
                title: "Cost / \(distanceUnit.shortLabel)",
                value: costPerDistance > 0 ? "\(currencySymbol)\(String(format: "%.3f", costPerDistance))" : "—"
            )
        }
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let title: String
    let value: String

    private static var cardBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(.secondarySystemBackground)
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Self.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
