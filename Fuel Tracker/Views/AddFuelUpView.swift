import SwiftUI
import SwiftData

/// Adds a new fill-up, or edits an existing one when `fuelUp` is supplied.
struct AddFuelUpView: View {
    let vehicle: Vehicle
    /// The fill-up being edited. `nil` means we're creating a new one.
    var fuelUp: FuelUp? = nil

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
    @State private var hasLoaded = false

    private var distanceUnit: DistanceUnit { DistanceUnit(rawValue: distanceUnitRaw) ?? .miles }
    private var volumeUnit: VolumeUnit { VolumeUnit(rawValue: volumeUnitRaw) ?? .liters }
    private var isEditing: Bool { fuelUp != nil }

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
            .navigationTitle(isEditing ? "Edit Fill-Up" : "New Fill-Up")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear { loadExistingIfNeeded() }
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

    /// Populates the fields from the existing fill-up the first time the form
    /// appears, converting stored units into the user's display units.
    private func loadExistingIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard let fuelUp else { return }

        date = fuelUp.date
        odometerText = trimmedNumber(UnitConversion.displayDistance(fuelUp.odometer, unit: distanceUnit))
        volumeText = trimmedNumber(UnitConversion.displayVolume(fuelUp.volume, unit: volumeUnit))
        totalCostText = String(format: "%.2f", fuelUp.totalCost)
        isFullTank = fuelUp.isFullTank
        notes = fuelUp.notes
    }

    private func trimmedNumber(_ value: Double) -> String {
        String(format: "%g", value)
    }

    private func save() {
        guard let odometerValue = Double(odometerText),
              let volumeValue = Double(volumeText),
              let costValue = Double(totalCostText) else { return }

        let storedOdometer = UnitConversion.storedDistance(fromDisplay: odometerValue, unit: distanceUnit)
        let storedVolume = UnitConversion.storedVolume(fromDisplay: volumeValue, unit: volumeUnit)

        if let fuelUp {
            // Editing: update the existing record in place.
            fuelUp.date = date
            fuelUp.odometer = storedOdometer
            fuelUp.volume = storedVolume
            fuelUp.totalCost = costValue
            fuelUp.isFullTank = isFullTank
            fuelUp.notes = notes
        } else {
            let newFuelUp = FuelUp(
                date: date,
                odometer: storedOdometer,
                volume: storedVolume,
                totalCost: costValue,
                isFullTank: isFullTank,
                notes: notes
            )
            newFuelUp.vehicle = vehicle
            vehicle.fuelUps.append(newFuelUp)
            modelContext.insert(newFuelUp)
        }

        try? modelContext.save()
        WidgetSync.refresh(for: vehicle)
        dismiss()
    }
}
