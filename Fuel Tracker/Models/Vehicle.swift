import Foundation
import SwiftData

@Model
final class Vehicle {
    var name: String
    var make: String
    var model: String
    var year: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \FuelUp.vehicle)
    var fuelUps: [FuelUp] = []

    init(
        name: String,
        make: String = "",
        model: String = "",
        year: Int = Calendar.current.component(.year, from: Date())
    ) {
        self.name = name
        self.make = make
        self.model = model
        self.year = year
        self.createdAt = Date()
    }
}
