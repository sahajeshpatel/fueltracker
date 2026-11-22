//
//  FuelWidget.swift
//  FuelWidget
//
//  Created by Sahajesh Patel on 31/07/2026.
//

import WidgetKit
import SwiftUI

// MARK: - Shared store

/// Mirror of the app's `WidgetSharedStore`. The app writes the latest
/// efficiency snapshot into the App Group container; the widget reads it here.
/// Keep these identifiers in sync with `WidgetSync.swift` in the app target.
private enum SharedStore {
    static let appGroupID = "group.sahajesh.Fuel-Tracker"

    enum Key {
        static let efficiencyValue = "widget.efficiencyValue"
        static let efficiencyUnitLabel = "widget.efficiencyUnitLabel"
        static let vehicleName = "widget.vehicleName"
        static let date = "widget.date"
        static let hasData = "widget.hasData"
    }

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }
}

// MARK: - Timeline entry

struct FuelEntry: TimelineEntry {
    let date: Date
    let hasData: Bool
    let efficiency: Double
    let unitLabel: String
    let vehicleName: String
    let recordedAt: Date?

    static let placeholder = FuelEntry(
        date: .now, hasData: true, efficiency: 42.3,
        unitLabel: "MPG", vehicleName: "My Car", recordedAt: .now
    )
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> FuelEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (FuelEntry) -> Void) {
        completion(context.isPreview ? .placeholder : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FuelEntry>) -> Void) {
        // The app drives updates via WidgetCenter.reloadAllTimelines(), so a
        // single non-expiring entry is enough.
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> FuelEntry {
        let defaults = SharedStore.defaults
        let name = defaults?.string(forKey: SharedStore.Key.vehicleName) ?? "My Car"

        guard let defaults, defaults.bool(forKey: SharedStore.Key.hasData) else {
            return FuelEntry(date: .now, hasData: false, efficiency: 0,
                             unitLabel: "MPG", vehicleName: name, recordedAt: nil)
        }

        let timestamp = defaults.double(forKey: SharedStore.Key.date)
        return FuelEntry(
            date: .now,
            hasData: true,
            efficiency: defaults.double(forKey: SharedStore.Key.efficiencyValue),
            unitLabel: defaults.string(forKey: SharedStore.Key.efficiencyUnitLabel) ?? "MPG",
            vehicleName: name,
            recordedAt: timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        )
    }
}

// MARK: - Views

struct FuelWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: FuelEntry

    private var valueText: String {
        entry.hasData ? String(format: "%.1f", entry.efficiency) : "—"
    }

    var body: some View {
        switch family {
        case .systemMedium: mediumView
        case .accessoryRectangular: rectangularView
        case .accessoryInline: inlineView
        case .accessoryCircular: circularView
        default: smallView
        }
    }

    // Home Screen — small
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: "fuelpump.fill")
                .font(.title3)
                .foregroundStyle(.tint)
            Spacer()
            Text(valueText)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(entry.unitLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.vehicleName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Home Screen — medium
    private var mediumView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Last Efficiency", systemImage: "fuelpump.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.vehicleName)
                    .font(.headline)
                    .lineLimit(1)
                if let recordedAt = entry.recordedAt {
                    Text(recordedAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(valueText)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(entry.unitLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxHeight: .infinity)
    }

    // Lock Screen — rectangular
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Last Efficiency", systemImage: "fuelpump.fill")
                .font(.caption2)
                .widgetAccentable()
            Text("\(valueText) \(entry.unitLabel)")
                .font(.headline)
            Text(entry.vehicleName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Lock Screen — inline (above the clock)
    private var inlineView: some View {
        Label("\(valueText) \(entry.unitLabel)", systemImage: "fuelpump.fill")
    }

    // Lock Screen — circular
    private var circularView: some View {
        VStack(spacing: 0) {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: 12))
                .widgetAccentable()
            Text(valueText)
                .font(.system(.headline, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(entry.unitLabel)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Widget

struct FuelWidget: Widget {
    let kind = "FuelWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FuelWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Fuel Efficiency")
        .description("Shows the most recent fuel efficiency for your vehicle.")
        .supportedFamilies(Self.supportedFamilies)
    }

    /// Lock Screen accessory families don't exist on macOS, so the Mac widget
    /// only offers the desktop sizes.
    private static var supportedFamilies: [WidgetFamily] {
        #if os(macOS)
        [.systemSmall, .systemMedium]
        #else
        [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular]
        #endif
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    FuelWidget()
} timeline: {
    FuelEntry.placeholder
}
