import Foundation
import CoreLocation

// MARK: - Shelter API Response

struct ShelterResponse: Codable {
    let count: Int
    let radius_m: Double
    let total_in_db: Int
    let shelters: [ShelterItem]
}

// MARK: - ShelterItem

struct ShelterItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let address: String?
    let lat: Double
    let lon: Double
    let distance_m: Double
    let type: String        // bomb_shelter | bunker | metro | underground
    let capacity: Int?
    let accessible: Bool
    let source: String      // osm | kyiv_open_data

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Human-readable type description in Ukrainian
    var typeDescription: String {
        switch type {
        case "bomb_shelter":         return "Бомбосховище"
        case "underground_parking":  return "Підземний паркінг"
        case "metro":                return "Станція метро"
        case "bunker":               return "Бункер"
        case "radiation_shelter":    return "Протирадіаційне укриття"
        case "underground":          return "Підземне укриття"
        default:                     return "Укриття цивільного захисту"
        }
    }

    /// Formatted distance string
    var distanceText: String {
        if distance_m < 1000 {
            return "\(Int(distance_m)) м"
        } else {
            return String(format: "%.1f км", distance_m / 1000)
        }
    }

    /// Icon name for this shelter type
    var iconName: String {
        switch type {
        case "metro":                return "tram.fill"
        case "underground_parking":  return "parkingsign.circle.fill"
        case "bunker":               return "shield.checkered"
        case "radiation_shelter":    return "shield.fill"
        case "underground":          return "arrow.down.to.line"
        default:                     return "shield.fill"
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ShelterItem, rhs: ShelterItem) -> Bool {
        lhs.id == rhs.id
    }
}
