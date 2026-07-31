import SwiftUI
import SwiftData

struct AddFuelUpView: View {
    let vehicle: Vehicle
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppStorageKeys.distanceUnit) private var distanceUnitRaw = DistanceUnit.miles.rawValue
    @AppStorage(AppStorageKeys.volumeUnit) private var volumeUnitRaw = VolumeUnit.liters.rawValue
    @AppStorage(AppStorageKeys.currencySymbol) private var currencySymbol = "£"

    @State private var date = Date()
    @State private var odometerText = ""
    @State private var volumeText = ""
    @State private var totalCostText = ""
    @State private var isFullTank = true
    @State private var notes = ""

    private var distanceUnit: DistanceUnit { DistanceUnit(rawValue: distanceUnitRaw) ?? .miles }
    private var volumeUnit: VolumeUnit { VolumeUnit(rawValue: volumeUnitRaw) ?? .liters }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fill-Up Details") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date])

                    HStack {
                        Text("Odometer")
                        Spacer()
                        TextField(distanceUnit.label, text: $odometerText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Volume")
                        Spacer()
                        TextField(volumeUnit.label, text: $volumeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Total Cost")
                        Spacer()
                        Text(currencySymbol)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $totalCostText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    Toggle("Filled to full tank", isOn: $isFullTank)
                }

                if let pricePerUnit {
                    Section {
                        HStack {
                            Text("Price per \(volumeUnit.shortLabel)")
                            Spacer()
                            Text("\(currencySymbol)\(pricePerUnit, specifier: "%.3f")")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("New Fill-Up")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var pricePerUnit: Double? {
        guard let volume = Double(volumeText), volume > 0,
              let cost = Double(totalCostText) else { return nil }
        return cost / volume
    }

    private var isValid: Bool {
        Double(odometerText) != nil && Double(volumeText) != nil && Double(totalCostText) != nil
    }

    private func save() {
        guard let odometerValue = Double(odometerText),
              let volumeValue = Double(volumeText),
              let costValue = Double(totalCostText) else { return }

        let storedOdometer = UnitConversion.storedDistance(fromDisplay: odometerValue, unit: distanceUnit)
        let storedVolume = UnitConversion.storedVolume(fromDisplay: volumeValue, unit: volumeUnit)

        let fuelUp = FuelUp(
            date: date,
            odometer: storedOdometer,
            volume: storedVolume,
            totalCost: costValue,
            isFullTank: isFullTank,
            notes: notes
        )
        fuelUp.vehicle = vehicle
        vehicle.fuelUps.append(fuelUp)
        modelContext.insert(fuelUp)
        try? modelContext.save()
        WidgetSync.refresh(for: vehicle)
        dismiss()
    }
}
