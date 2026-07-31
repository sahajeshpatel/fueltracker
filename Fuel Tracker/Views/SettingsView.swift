import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    let vehicle: Vehicle
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppStorageKeys.distanceUnit) private var distanceUnitRaw = DistanceUnit.miles.rawValue
    @AppStorage(AppStorageKeys.volumeUnit) private var volumeUnitRaw = VolumeUnit.liters.rawValue
    @AppStorage(AppStorageKeys.efficiencyUnit) private var efficiencyUnitRaw = EfficiencyUnit.mpgUK.rawValue
    @AppStorage(AppStorageKeys.currencySymbol) private var currencySymbol = "£"

    @State private var name: String = ""
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var year: Int = Calendar.current.component(.year, from: Date())

    @State private var showingImporter = false
    @State private var importResultTitle = ""
    @State private var importResultMessage = ""
    @State private var showingImportResult = false

    private var yearLabel: String {
        "Year: \(String(year))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle") {
                    TextField("Name", text: $name)
                        .onChange(of: name) { _, newValue in
                            vehicle.name = newValue
                            try? modelContext.save()
                        }
                    TextField("Make", text: $make)
                        .onChange(of: make) { _, newValue in
                            vehicle.make = newValue
                            try? modelContext.save()
                        }
                    TextField("Model", text: $model)
                        .onChange(of: model) { _, newValue in
                            vehicle.model = newValue
                            try? modelContext.save()
                        }
                    Stepper(yearLabel, value: $year, in: 1950...2100)
                        .onChange(of: year) { _, newValue in
                            vehicle.year = newValue
                            try? modelContext.save()
                        }
                }

                Section("Units") {
                    Picker("Distance", selection: $distanceUnitRaw) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.label).tag(unit.rawValue)
                        }
                    }
                    Picker("Fuel Volume", selection: $volumeUnitRaw) {
                        ForEach(VolumeUnit.allCases) { unit in
                            Text(unit.label).tag(unit.rawValue)
                        }
                    }
                    Picker("Efficiency Display", selection: $efficiencyUnitRaw) {
                        ForEach(EfficiencyUnit.allCases) { unit in
                            Text(unit.label).tag(unit.rawValue)
                        }
                    }
                    .onChange(of: efficiencyUnitRaw) { WidgetSync.refresh(for: vehicle) }
                }

                Section("Currency") {
                    TextField("Currency Symbol", text: $currencySymbol)
                }

                Section {
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import from Fuelly (CSV)", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Import a CSV exported from Fuelly. Fuel-ups already logged for this vehicle are skipped.")
                }

                Section {
                    Text("Fuel Tracker v1.0")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                name = vehicle.name
                make = vehicle.make
                model = vehicle.model
                year = vehicle.year
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert(importResultTitle, isPresented: $showingImportResult) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importResultMessage)
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importResultTitle = "Import Failed"
            importResultMessage = error.localizedDescription
            showingImportResult = true

        case .success(let urls):
            guard let url = urls.first else { return }

            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let parsed = try FuellyCSVImporter.parse(text)
                importParsedFuelUps(parsed)
            } catch {
                importResultTitle = "Import Failed"
                importResultMessage = error.localizedDescription
                showingImportResult = true
            }
        }
    }

    private func importParsedFuelUps(_ parsed: [FuellyCSVImporter.ParsedFuelUp]) {
        // Skip fuel-ups that already exist, matching on date and odometer so a
        // file can be re-imported without creating duplicates.
        let existingKeys = Set(vehicle.fuelUps.map { importKey(date: $0.date, odometer: $0.odometer) })

        // Adopt the name from the export if the vehicle is still the default and
        // the file names one, so the imported log isn't stuck under "My Car".
        if vehicle.name == "My Car",
           let importedName = parsed.first(where: { !$0.vehicleName.isEmpty })?.vehicleName {
            vehicle.name = importedName
            name = importedName
        }

        var imported = 0
        var skipped = 0
        for row in parsed {
            let key = importKey(date: row.date, odometer: row.odometer)
            guard !existingKeys.contains(key) else {
                skipped += 1
                continue
            }
            let fuelUp = FuelUp(
                date: row.date,
                odometer: row.odometer,
                volume: row.volume,
                totalCost: row.totalCost,
                isFullTank: row.isFullTank,
                notes: row.notes
            )
            fuelUp.vehicle = vehicle
            vehicle.fuelUps.append(fuelUp)
            modelContext.insert(fuelUp)
            imported += 1
        }

        try? modelContext.save()
        WidgetSync.refresh(for: vehicle)

        importResultTitle = "Import Complete"
        var lines = ["Imported \(imported) fuel-up\(imported == 1 ? "" : "s")."]
        if skipped > 0 {
            lines.append("Skipped \(skipped) already in your log.")
        }
        importResultMessage = lines.joined(separator: "\n")
        showingImportResult = true
    }

    /// A stable key used to detect duplicate fuel-ups on import.
    private func importKey(date: Date, odometer: Double) -> String {
        "\(Int(date.timeIntervalSince1970))-\(Int(odometer.rounded()))"
    }
}
