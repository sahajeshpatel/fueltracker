import SwiftUI
import SwiftData

@main
struct FuelTrackerApp: App {
    /// Stores data locally and mirrors it to the user's private iCloud
    /// database, so fuel-ups sync between their iPhone, iPad and Mac.
    let modelContainer: ModelContainer = {
        let schema = Schema([Vehicle.self, FuelUp.self])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.sahajesh.Fuel-Tracker")
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
