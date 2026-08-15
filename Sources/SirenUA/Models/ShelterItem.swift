import Foundation
import CoreLocation

// MARK: - Shelter API Response

struct ShelterResponse: Codable {
    let count: Int
    let radius_m: Double
    let total_in_db: Int
    let shelters: [ShelterItem]
}

// MARK: - Shelter Type Enumeration

enum ShelterType: String, Codable, CaseIterable {
    case bombShelter = "bomb_shelter"
    case undergroundParking = "underground_parking"
    case metro = "metro"
    case bunker = "bunker"
    case radiationShelter = "radiation_shelter"
    case schoolShelter = "school_shelter"
    case hospitalShelter = "hospital_shelter"
    case adminShelter = "admin_shelter"
    case basicShelter = "basic_shelter"
    case underground = "underground"
    case civilDefense = "civil_defense"

    var title: String {
        switch self {
        case .bombShelter:         return "Бомбосховище"
        case .undergroundParking:  return "Підземний паркінг"
        case .metro:               return "Станція метро"
        case .bunker:              return "Бункер"
        case .radiationShelter:    return "Протирадіаційне укриття"
        case .schoolShelter:       return "Найпростіше укриття (Школа / Ліцей)"
        case .hospitalShelter:     return "Медичний заклад (ПРУ / Підвал)"
        case .adminShelter:        return "Адміністративна будівля (Старостат)"
        case .basicShelter:        return "Найпростіше укриття"
        case .underground:         return "Підземне укриття"
        case .civilDefense:        return "Укриття цивільного захисту"
        }
    }

    var iconName: String {
        switch self {
        case .metro:               return "tram.fill"
        case .undergroundParking:  return "parkingsign.circle.fill"
        case .bunker:              return "shield.checkered"
        case .radiationShelter:    return "radiation"
        case .schoolShelter:       return "graduationcap.fill"
        case .hospitalShelter:     return "cross.case.fill"
        case .adminShelter:        return "building.columns.fill"
        case .basicShelter:        return "shield.checkered"
        case .underground:         return "arrow.down.to.line"
        case .bombShelter, .civilDefense:
            return "shield.fill"
        }
    }

    /// Determines the shelter type based on string tags or query names.
    static func matching(from rawType: String?, name: String? = nil) -> ShelterType {
        if let raw = rawType?.lowercased() {
            switch raw {
            case "metro", "subway":
                return .metro
            case "underground_parking", "parking":
                return .undergroundParking
            case "bunker":
                return .bunker
            case "radiation_shelter", "anti_radiation", "radiation":
                return .radiationShelter
            case "school_shelter", "school", "kindergarten":
                return .schoolShelter
            case "hospital_shelter", "hospital", "clinic":
                return .hospitalShelter
            case "admin_shelter", "admin", "townhall":
                return .adminShelter
            case "basic_shelter":
                return .basicShelter
            case "underground":
                return .underground
            case "bomb_shelter":
                return .bombShelter
            default:
                break
            }
        }

        guard let name = name?.lowercased(), !name.isEmpty else {
            return .civilDefense
        }

        if name.contains("метро") || name.contains("subway") {
            return .metro
        } else if name.contains("паркінг") || name.contains("парковка") || name.contains("parking") {
            return .undergroundParking
        } else if name.contains("протирадіаційн") || name.contains("пру") || name.contains("радіаці") {
            return .radiationShelter
        } else if name.contains("бункер") || name.contains("bunker") {
            return .bunker
        } else if name.contains("ліцей") || name.contains("школа") || name.contains("гімназія") || name.contains("дитсадок") || name.contains("садочок") || name.contains("здо") {
            return .schoolShelter
        } else if name.contains("лікарня") || name.contains("поліклініка") || name.contains("амбулаторія") || name.contains("госпіталь") {
            return .hospitalShelter
        } else if name.contains("старостат") || name.contains("сільрада") || name.contains("сільська рада") || name.contains("міська рада") || name.contains("будинок культури") {
            return .adminShelter
        } else if name.contains("підземн") || name.contains("перехід") {
            return .underground
        } else {
            return .civilDefense
        }
    }

    /// Returns the standardized SF Symbol icon for a shelter name and optional type.
    static func iconName(for name: String, type: String? = nil) -> String {
        matching(from: type, name: name).iconName
    }
}

// MARK: - Shelter Formatter

enum ShelterFormatter {
    /// Formats distance in meters to a localized Ukrainian string (e.g. "450 м" or "2.3 км").
    static func formatDistance(meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters)) м"
        } else {
            return String(format: "%.1f км", meters / 1000.0)
        }
    }

    /// Formats route travel time in seconds to a human-readable string (e.g. "5 хв", "1 год 15 хв").
    static func formatTravelTime(seconds: TimeInterval) -> String {
        let totalMinutes = max(1, Int(seconds / 60))
        if totalMinutes < 60 {
            return "\(totalMinutes) хв"
        } else {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return mins > 0 ? "\(hours) год \(mins) хв" : "\(hours) год"
        }
    }
}

// MARK: - ShelterItem

struct ShelterItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let address: String?
    let lat: Double
    let lon: Double
    let distance_m: Double
    let type: String        // bomb_shelter | bunker | metro | underground | underground_parking | radiation_shelter
    let capacity: Int?
    let accessible: Bool
    let source: String      // osm | gov | kyiv_open_data

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var shelterType: ShelterType {
        ShelterType.matching(from: type, name: name)
    }

    /// Human-readable type description in Ukrainian
    var typeDescription: String {
        shelterType.title
    }

    /// Formatted distance string
    var distanceText: String {
        ShelterFormatter.formatDistance(meters: distance_m)
    }

    /// Icon name for this shelter type
    var iconName: String {
        shelterType.iconName
    }

    /// Full descriptive display name for map pins and lists
    var displayName: String {
        let baseName = (name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? typeDescription
        if let address = address?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
            return "\(baseName) — \(address)"
        }
        return baseName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ShelterItem, rhs: ShelterItem) -> Bool {
        lhs.id == rhs.id
    }
}
