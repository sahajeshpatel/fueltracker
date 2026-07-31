import Foundation

enum DistanceUnit: String, CaseIterable, Identifiable {
    case miles, kilometers

    var id: String { rawValue }

    var label: String { self == .miles ? "Miles" : "Kilometers" }
    var shortLabel: String { self == .miles ? "mi" : "km" }
}

enum VolumeUnit: String, CaseIterable, Identifiable {
    case liters, usGallons, ukGallons

    var id: String { rawValue }

    var label: String {
        switch self {
        case .liters: return "Liters"
        case .usGallons: return "US Gallons"
        case .ukGallons: return "UK Gallons"
        }
    }

    var shortLabel: String {
        switch self {
        case .liters: return "L"
        case .usGallons: return "gal (US)"
        case .ukGallons: return "gal (UK)"
        }
    }
}

enum EfficiencyUnit: String, CaseIterable, Identifiable {
    case mpgUS, mpgUK, litersPer100km, kmPerLiter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mpgUS: return "MPG (US Gallons)"
        case .mpgUK: return "MPG (UK Gallons)"
        case .litersPer100km: return "Liters / 100km"
        case .kmPerLiter: return "Kilometers / Liter"
        }
    }

    var shortLabel: String {
        switch self {
        case .mpgUS, .mpgUK: return "MPG"
        case .litersPer100km: return "L/100km"
        case .kmPerLiter: return "km/L"
        }
    }
}

/// All conversions go through canonical storage units: distance in miles, volume in liters.
enum UnitConversion {

    static func milesToKm(_ miles: Double) -> Double { miles * 1.60934 }
    static func kmToMiles(_ km: Double) -> Double { km / 1.60934 }

    static func litersToUSGallons(_ liters: Double) -> Double { liters / 3.78541 }
    static func litersToUKGallons(_ liters: Double) -> Double { liters / 4.54609 }
    static func usGallonsToLiters(_ gallons: Double) -> Double { gallons * 3.78541 }
    static func ukGallonsToLiters(_ gallons: Double) -> Double { gallons * 4.54609 }

    static func displayDistance(_ miles: Double, unit: DistanceUnit) -> Double {
        unit == .miles ? miles : milesToKm(miles)
    }

    static func storedDistance(fromDisplay value: Double, unit: DistanceUnit) -> Double {
        unit == .miles ? value : kmToMiles(value)
    }

    static func displayVolume(_ liters: Double, unit: VolumeUnit) -> Double {
        switch unit {
        case .liters: return liters
        case .usGallons: return litersToUSGallons(liters)
        case .ukGallons: return litersToUKGallons(liters)
        }
    }

    static func storedVolume(fromDisplay value: Double, unit: VolumeUnit) -> Double {
        switch unit {
        case .liters: return value
        case .usGallons: return usGallonsToLiters(value)
        case .ukGallons: return ukGallonsToLiters(value)
        }
    }

    static func efficiency(distanceMiles: Double, volumeLiters: Double, unit: EfficiencyUnit) -> Double {
        guard distanceMiles > 0, volumeLiters > 0 else { return 0 }
        switch unit {
        case .mpgUS:
            return distanceMiles / litersToUSGallons(volumeLiters)
        case .mpgUK:
            return distanceMiles / litersToUKGallons(volumeLiters)
        case .litersPer100km:
            let km = milesToKm(distanceMiles)
            return (volumeLiters / km) * 100
        case .kmPerLiter:
            let km = milesToKm(distanceMiles)
            return km / volumeLiters
        }
    }
}
