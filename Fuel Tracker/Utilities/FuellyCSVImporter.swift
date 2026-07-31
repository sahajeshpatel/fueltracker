import Foundation

/// Parses a Fuelly CSV export into fuel-up records ready to insert into SwiftData.
///
/// Fuelly exports one header row followed by one row per fuel-up. The columns we
/// care about are: `Date`, `Time`, `Odometer` (miles), `Filled Up`, `Liters`,
/// `Total Cost`, `Location`, `Gas Brand` and `Notes`. Odometer and total cost may
/// contain thousands separators or a currency symbol, and any field may be quoted
/// when it contains a comma (e.g. `"1,126"` or `"Costco, Sheffield"`).
enum FuellyCSVImporter {

    /// A single parsed fuel-up, already in the app's canonical storage units
    /// (distance in miles, volume in liters).
    struct ParsedFuelUp {
        var date: Date
        var odometer: Double
        var volume: Double
        var totalCost: Double
        var isFullTank: Bool
        var notes: String
        /// The `Vehicle` column value, if present, so the caller can adopt it.
        var vehicleName: String
    }

    enum ImportError: LocalizedError {
        case emptyFile
        case missingColumns([String])
        case noValidRows

        var errorDescription: String? {
            switch self {
            case .emptyFile:
                return "The file appears to be empty."
            case .missingColumns(let columns):
                return "This doesn't look like a Fuelly export. Missing columns: \(columns.joined(separator: ", "))."
            case .noValidRows:
                return "No fuel-ups could be read from the file."
            }
        }
    }

    /// Parses the raw text of a Fuelly CSV export.
    static func parse(_ text: String) throws -> [ParsedFuelUp] {
        let rows = parseRows(text)
        guard let header = rows.first else { throw ImportError.emptyFile }

        let index = columnIndex(from: header)
        let required = ["Date", "Odometer", "Liters", "Total Cost"]
        let missing = required.filter { index[$0.lowercased()] == nil }
        guard missing.isEmpty else { throw ImportError.missingColumns(missing) }

        func value(_ column: String, in row: [String]) -> String {
            guard let i = index[column.lowercased()], i < row.count else { return "" }
            return row[i].trimmingCharacters(in: .whitespaces)
        }

        var results: [ParsedFuelUp] = []
        for row in rows.dropFirst() {
            // Skip blank lines produced by a trailing newline.
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { continue }

            guard let date = parseDate(value("Date", in: row), time: value("Time", in: row)),
                  let odometer = parseNumber(value("Odometer", in: row)),
                  let volume = parseNumber(value("Liters", in: row)),
                  let totalCost = parseNumber(value("Total Cost", in: row)) else { continue }

            // Rows with no odometer or no fuel aren't useful fuel-ups.
            guard odometer > 0, volume > 0 else { continue }

            let filledUp = value("Filled Up", in: row).lowercased()
            let isFullTank = filledUp == "full"

            results.append(
                ParsedFuelUp(
                    date: date,
                    odometer: odometer,
                    volume: volume,
                    totalCost: totalCost,
                    isFullTank: isFullTank,
                    notes: composeNotes(
                        notes: value("Notes", in: row),
                        location: value("Location", in: row),
                        brand: value("Gas Brand", in: row)
                    ),
                    vehicleName: value("Vehicle", in: row)
                )
            )
        }

        guard !results.isEmpty else { throw ImportError.noValidRows }
        return results
    }

    // MARK: - Field helpers

    /// Maps lowercased column names to their position in the header row.
    private static func columnIndex(from header: [String]) -> [String: Int] {
        var index: [String: Int] = [:]
        for (i, name) in header.enumerated() {
            index[name.trimmingCharacters(in: .whitespaces).lowercased()] = i
        }
        return index
    }

    /// Fuelly writes dates as `dd/MM/yyyy` and times as `HH:mm`.
    private static func parseDate(_ dateString: String, time: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        if !time.isEmpty {
            formatter.dateFormat = "dd/MM/yyyy HH:mm"
            if let date = formatter.date(from: "\(dateString) \(time)") { return date }
        }
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.date(from: dateString)
    }

    /// Strips currency symbols and thousands separators, keeping digits, a decimal
    /// point and a leading minus sign.
    private static func parseNumber(_ string: String) -> Double? {
        let cleaned = string.filter { $0.isNumber || $0 == "." || $0 == "-" }
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    /// Keeps any Fuelly detail worth preserving, preferring the explicit notes
    /// field and falling back to the station location and brand.
    private static func composeNotes(notes: String, location: String, brand: String) -> String {
        if !notes.isEmpty { return notes }
        let place = [brand, location].filter { !$0.isEmpty }.joined(separator: " – ")
        return place
    }

    // MARK: - CSV tokenizer

    /// Splits CSV text into rows of fields, honouring quoted fields that may
    /// contain commas, escaped quotes (`""`) and newlines.
    private static func parseRows(_ text: String) -> [[String]] {
        // Swift treats a `\r\n` (CRLF) sequence as a single Character grapheme
        // cluster, which wouldn't match the `\n` case below. Normalise all line
        // endings to `\n` first so row splitting is reliable across platforms.
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false

        var iterator = normalized.makeIterator()
        var pending: Character? = nil

        func next() -> Character? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }

        while let character = next() {
            if inQuotes {
                if character == "\"" {
                    if let following = next() {
                        if following == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            pending = following
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    inQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\r":
                    break
                case "\n":
                    row.append(field)
                    field = ""
                    rows.append(row)
                    row = []
                default:
                    field.append(character)
                }
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}
