import SwiftUI
import SwiftData

@main
struct FuelTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Vehicle.self, FuelUp.self])
    }
}
