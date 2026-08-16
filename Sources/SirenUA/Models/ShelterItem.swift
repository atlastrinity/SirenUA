import Foundation
import CoreLocation

// MARK: - Shelter API Response

struct ShelterResponse: Codable {
    let count: Int
    let radius_m: Double?
    let region_code: String?
    let region_name: String?
    let primary_count: Int?
    let secondary_count: Int?
    let total_in_db: Int?
    let shelters: [ShelterItem]
}

struct ShelterRegionSummary: Codable, Identifiable {
    var id: String { region_code }
    let region_code: String
    let region_name: String
    let centroid_lat: Double
    let centroid_lon: Double
    let total_count: Int
    let primary_count: Int
    let secondary_count: Int
}

struct ShelterRegionsResponse: Codable {
    let total_regions: Int
    let total_shelters: Int
    let total_primary: Int
    let total_secondary: Int
    let regions: [ShelterRegionSummary]
}

// MARK: - Shelter Category
enum ShelterCategory: String, Codable {
    case primary    // Офіційні бомбосховища, бункери, метро, ПРУ, ЦЗ
    case secondary  // Альтернативні укриття: ТРЦ паркінги, школи, лікарні, адмінбудівлі

    var title: String {
        switch self {
        case .primary:   return "Офіційне сховище"
        case .secondary: return "Альтернативне укриття"
        }
    }
}

// MARK: - Shelter Type Enumeration

enum ShelterType: String, Codable, CaseIterable {
    case bombShelter = "bomb_shelter"
    case mallParking = "mall_parking"
    case undergroundParking = "underground_parking"
    case openParking = "open_parking"
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
        case .mallParking:         return "Паркінг ТРЦ (Цілодобовий заїзд)"
        case .undergroundParking:  return "Підземний паркінг"
        case .openParking:         return "Відкритий / Критий паркінг"
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
        case .mallParking:         return "parkingsign.circle.fill"
        case .undergroundParking:  return "parkingsign.circle.fill"
        case .openParking:         return "car.fill"
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

    /// Category: primary official civil defense vs secondary/alternative
    var category: ShelterCategory {
        switch self {
        case .bombShelter, .metro, .bunker, .radiationShelter, .civilDefense:
            return .primary
        case .mallParking, .undergroundParking, .openParking, .schoolShelter, .hospitalShelter, .adminShelter, .basicShelter, .underground:
            return .secondary
        }
    }

    /// Whether this shelter is accessible 24/7 during night hours
    var isNightAccessible: Bool {
        switch self {
        case .metro, .bombShelter, .bunker, .radiationShelter, .civilDefense, .mallParking, .undergroundParking, .openParking, .hospitalShelter, .underground:
            return true
        case .schoolShelter, .adminShelter, .basicShelter:
            return false
        }
    }

    /// Whether this shelter supports direct automobile parking / shelter
    var isVehicleAccessible: Bool {
        switch self {
        case .mallParking, .undergroundParking, .openParking:
            return true
        default:
            return false
        }
    }

    /// Short descriptive badge text for cards and maps
    var badgeText: String {
        switch self {
        case .mallParking:         return "Паркінг ТРЦ • Авто"
        case .undergroundParking:  return "Підземний паркінг"
        case .openParking:         return "Паркінг для авто"
        case .metro:               return "Станція метро"
        case .bunker:              return "Спецбункер"
        case .radiationShelter:    return "ПРУ сховище"
        case .schoolShelter:       return "Школа / Ліцей"
        case .hospitalShelter:     return "Лікарня (ПРУ)"
        case .adminShelter:        return "Адмінбудівля"
        case .underground:         return "Підземний перехід"
        case .bombShelter, .civilDefense, .basicShelter:
            return "Офіційне сховище"
        }
    }

    /// Determines the shelter type based on string tags or query names.
    static func matching(from rawType: String?, name: String? = nil) -> ShelterType {
        let nameLower = (name ?? "").lowercased()
        let isMallKeywords = nameLower.contains("трц") || nameLower.contains("тц") || nameLower.contains("mall") ||
                             nameLower.contains("плаза") || nameLower.contains("plaza") || nameLower.contains("центр") ||
                             nameLower.contains("епіцентр") || nameLower.contains("ретровиль") || nameLower.contains("retroville") ||
                             nameLower.contains("lavina") || nameLower.contains("лавина") || nameLower.contains("forum") ||
                             nameLower.contains("форум") || nameLower.contains("king cross") || nameLower.contains("кінг крос") ||
                             nameLower.contains("караван") || nameLower.contains("мост-сіті") || nameLower.contains("most city") ||
                             nameLower.contains("нікольський") || nameLower.contains("nikolsky") || nameLower.contains("дафі") ||
                             nameLower.contains("dafi") || nameLower.contains("сіті центр") || nameLower.contains("city center") ||
                             nameLower.contains("рів'єра") || nameLower.contains("riviera") || nameLower.contains("river mall") ||
                             nameLower.contains("respublika") || nameLower.contains("республіка") || nameLower.contains("skymall") ||
                             nameLower.contains("скаймол") || nameLower.contains("dream") || nameLower.contains("дрім") ||
                             nameLower.contains("gulliver") || nameLower.contains("гуллівер") || nameLower.contains("гулівер") ||
                             nameLower.contains("мегамолл") || nameLower.contains("екватор") || nameLower.contains("victoria gardens")

        let isParkingKeywords = nameLower.contains("паркінг") || nameLower.contains("парковка") || nameLower.contains("автостоянка") || nameLower.contains("parking")

        if let raw = rawType?.lowercased() {
            switch raw {
            case "mall_parking":
                return .mallParking
            case "open_parking":
                return .openParking
            case "metro", "subway":
                return .metro
            case "underground_parking", "parking":
                return isMallKeywords ? .mallParking : .undergroundParking
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

        guard !nameLower.isEmpty else {
            return .civilDefense
        }

        if nameLower.contains("метро") || nameLower.contains("subway") {
            return .metro
        } else if (isParkingKeywords && isMallKeywords) || (isMallKeywords && (nameLower.contains("парк") || nameLower.contains("авто") || !nameLower.contains("ліцей"))) {
            return .mallParking
        } else if isParkingKeywords {
            return .undergroundParking
        } else if nameLower.contains("протирадіаційн") || nameLower.contains("пру") || nameLower.contains("радіаці") {
            return .radiationShelter
        } else if nameLower.contains("бункер") || nameLower.contains("bunker") {
            return .bunker
        } else if nameLower.contains("ліцей") || nameLower.contains("школа") || nameLower.contains("гімназія") || nameLower.contains("дитсадок") || nameLower.contains("садочок") || nameLower.contains("здо") {
            return .schoolShelter
        } else if nameLower.contains("лікарня") || nameLower.contains("поліклініка") || nameLower.contains("амбулаторія") || nameLower.contains("госпіталь") {
            return .hospitalShelter
        } else if nameLower.contains("старостат") || nameLower.contains("сільрада") || nameLower.contains("сільська рада") || nameLower.contains("міська рада") || nameLower.contains("будинок культури") {
            return .adminShelter
        } else if nameLower.contains("підземн") || nameLower.contains("перехід") {
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
    let type: String        // bomb_shelter | bunker | metro | underground | underground_parking | mall_parking | radiation_shelter
    let capacity: Int?
    let accessible: Bool
    let source: String      // osm | gov | kyiv_open_data
    let is_primary: Bool?
    let is_night_accessible: Bool?
    let is_vehicle_accessible: Bool?

    init(
        id: String,
        name: String? = nil,
        address: String? = nil,
        lat: Double,
        lon: Double,
        distance_m: Double = 0.0,
        type: String,
        capacity: Int? = nil,
        accessible: Bool = true,
        source: String = "osm",
        is_primary: Bool? = nil,
        is_night_accessible: Bool? = nil,
        is_vehicle_accessible: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.lat = lat
        self.lon = lon
        self.distance_m = distance_m
        self.type = type
        self.capacity = capacity
        self.accessible = accessible
        self.source = source
        self.is_primary = is_primary
        self.is_night_accessible = is_night_accessible
        self.is_vehicle_accessible = is_vehicle_accessible
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var shelterType: ShelterType {
        ShelterType.matching(from: type, name: name)
    }

    var category: ShelterCategory {
        if let primary = is_primary {
            return primary ? .primary : .secondary
        }
        return shelterType.category
    }

    var isNightAccessible: Bool {
        is_night_accessible ?? shelterType.isNightAccessible
    }

    var isVehicleAccessible: Bool {
        is_vehicle_accessible ?? shelterType.isVehicleAccessible
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
