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

    @State private var showingExporter = false
    @State private var showingBackupImporter = false
    @State private var exportDocument = JSONDocument(data: Data())

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
                    Button {
                        exportBackup()
                    } label: {
                        Label("Export backup", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showingBackupImporter = true
                    } label: {
                        Label("Import backup", systemImage: "tray.and.arrow.down")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Export writes a JSON file you can save anywhere, including iCloud Drive. Importing adds any fuel-ups not already in your log; nothing is deleted.")
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
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: suggestedBackupFilename
            ) { result in
                switch result {
                case .success:
                    importResultTitle = "Backup Saved"
                    importResultMessage = "Your vehicle details and fuel-ups were exported."
                case .failure(let error):
                    importResultTitle = "Export Failed"
                    importResultMessage = error.localizedDescription
                }
                showingImportResult = true
            }
            .fileImporter(
                isPresented: $showingBackupImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { performBackupImport(url) }
                case .failure(let error):
                    importResultTitle = "Import Failed"
                    importResultMessage = error.localizedDescription
                    showingImportResult = true
                }
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
        let existingKeys = Set((vehicle.fuelUps ?? []).map { importKey(date: $0.date, odometer: $0.odometer) })

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

    // MARK: - JSON backup

    private var suggestedBackupFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let safeName = vehicle.name.replacingOccurrences(of: "/", with: "-")
        return "FuelTracker-\(safeName)-\(formatter.string(from: Date()))"
    }

    private func exportBackup() {
        do {
            exportDocument = JSONDocument(data: try FuelBackup(vehicle: vehicle).encoded())
            showingExporter = true
        } catch {
            importResultTitle = "Export Failed"
            importResultMessage = error.localizedDescription
            showingImportResult = true
        }
    }

    private func performBackupImport(_ url: URL) {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            merge(try FuelBackup.decoded(from: data))
        } catch {
            importResultTitle = "Import Failed"
            importResultMessage = "That file isn't a Fuel Tracker backup, or it's damaged."
            showingImportResult = true
        }
    }

    /// Adds any fuel-ups the log doesn't already have. Existing entries are
    /// left alone, so a backup can be imported more than once safely.
    private func merge(_ backup: FuelBackup) {
        let existingKeys = Set((vehicle.fuelUps ?? []).map { importKey(date: $0.date, odometer: $0.odometer) })

        var imported = 0
        var skipped = 0
        for row in backup.fuelUps {
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
            modelContext.insert(fuelUp)
            imported += 1
        }

        if vehicle.name == "My Car", !backup.vehicle.name.isEmpty {
            vehicle.name = backup.vehicle.name
            name = backup.vehicle.name
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
}

/// A portable snapshot of a vehicle and its fuel-ups. Deliberately separate
/// from the SwiftData models so the backup format stays stable even if the
/// persistence layer changes.
struct FuelBackup: Codable {
    var formatVersion: Int = 1
    var exportedAt: Date = Date()
    var vehicle: VehicleSnapshot
    var fuelUps: [FuelUpSnapshot]

    struct VehicleSnapshot: Codable {
        var name: String
        var make: String
        var model: String
        var year: Int
    }

    struct FuelUpSnapshot: Codable {
        var date: Date
        var odometer: Double
        var volume: Double
        var totalCost: Double
        var isFullTank: Bool
        var notes: String
    }

    init(vehicle: Vehicle) {
        self.vehicle = VehicleSnapshot(
            name: vehicle.name,
            make: vehicle.make,
            model: vehicle.model,
            year: vehicle.year
        )
        self.fuelUps = (vehicle.fuelUps ?? []).sorted { $0.date < $1.date }
            .map {
                FuelUpSnapshot(
                    date: $0.date,
                    odometer: $0.odometer,
                    volume: $0.volume,
                    totalCost: $0.totalCost,
                    isFullTank: $0.isFullTank,
                    notes: $0.notes
                )
            }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decoded(from data: Data) throws -> FuelBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FuelBackup.self, from: data)
    }
}

/// Minimal wrapper so `.fileExporter` can write raw JSON data.
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
