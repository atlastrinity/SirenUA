import Foundation
import MapKit
import SwiftUI

struct AlertRegion: Identifiable, Codable, Equatable {
    static func == (lhs: AlertRegion, rhs: AlertRegion) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.isActive == rhs.isActive &&
               lhs.level == rhs.level &&
               lhs.description == rhs.description &&
               lhs.threatLevel == rhs.threatLevel &&
               lhs.threatType == rhs.threatType &&
               lhs.threatDetail == rhs.threatDetail &&
               lhs.threatConfidence == rhs.threatConfidence &&
               lhs.threatETA == rhs.threatETA &&
               lhs.isThreatPredictive == rhs.isThreatPredictive &&
               lhs.activeThreats == rhs.activeThreats &&
               lhs.selectedThreatIndex == rhs.selectedThreatIndex
    }
    let id: Int
    let name: String
    var isActive: Bool
    var level: Int
    var description: String
    let coordinate: CLLocationCoordinate2D
    var lastChanged: String?
    
    private var _threatLevel: String? = nil
    var threatLevel: String? {
        get { return _threatLevel }
        set { _threatLevel = newValue }
    }
    
    private var _threatType: String? = nil
    var threatType: String? {
        get { return _threatType }
        set { _threatType = newValue }
    }
    
    private var _threatDetail: String? = nil
    var threatDetail: String? {
        get { return _threatDetail }
        set { _threatDetail = newValue }
    }
    
    var threatConfidence: Int? // 0-100% AI confidence score
    var threatETA: String?     // "~20-40 хв" expected arrival time
    var isThreatPredictive: Bool = false // true if AI-predicted route
    var officialAlertType: String? = nil // "artillery" | "urban_fights" | "chemical" | "nuclear" | "air"
    var activeThreats: [SingleThreatInfo] = [] // Масив усіх активних загроз
    var activeDistricts: [String] = []       // Масив районів у зоні тривоги
    var selectedThreatIndex: Int = 0             // Індекс вибраної загрози для UI

    /// Поточна вибрана загроза для відображення у картці
    var currentThreat: SingleThreatInfo? {
        guard !activeThreats.isEmpty else { return nil }
        let idx = min(selectedThreatIndex, activeThreats.count - 1)
        return activeThreats[idx]
    }

    /// Динамічне значення ETA з урахуванням поточного часу
    var displayETA: String? {
        if let current = currentThreat {
            return current.dynamicETA
        }
        return threatETA
    }

    private var activeThreatsExpired: Bool {
        return false
    }

    /// Кількість активних загроз різних типів
    var threatCount: Int { activeThreats.count }

    var icon: String {
        if isActive {
            if let offType = officialAlertType?.lowercased(), offType != "air" && !offType.isEmpty {
                return ThreatConstants.sfSymbol(for: offType)
            }
            switch level {
            case 1: return "exclamationmark.triangle.fill"
            case 2: return "bell.fill"
            case 3: return "speaker.wave.3.fill"
            default: return "speaker.wave.3.fill"
            }
        } else if threatLevel != nil {
            return ThreatConstants.sfSymbol(for: threatType)
        }
        return "info.circle.fill"
    }

    var color: Color {
        if isActive {
            switch level {
            case 1: return .yellow
            case 2: return .orange
            case 3: return .red
            default: return .red
            }
        } else if threatLevel != nil || !activeThreats.isEmpty {
            let threat = threatLevel ?? activeThreats.first?.level ?? "low"
            
            // Загрози без офіційної тривоги (isActive == false) — ВИКЛЮЧНО жовта гама
            // Від світло-жовтого для низьких/прогнозних до темнішого інтенсивного жовтого (Amber) для високих загроз
            switch threat {
            case "critical", "high":
                return Color(red: 0.96, green: 0.75, blue: 0.05) // Інтенсивний темніший жовтий (Deep Amber Yellow)
            case "medium":
                return Color(red: 0.98, green: 0.84, blue: 0.12) // Помірний яскравій жовтий
            case "low":
                return Color(red: 0.98, green: 0.90, blue: 0.35) // Світло-жовтий
            default:
                return Color(red: 0.98, green: 0.84, blue: 0.12)
            }
        }
        return .blue
    }

    /// Перевіряє, чи активна тривога в конкретному районі цієї області
    func isDistrictActive(_ districtName: String) -> Bool {
        guard isActive else { return false }
        if activeDistricts.isEmpty {
            // Якщо список районів порожній — тривога оголошена по всій області
            return true
        }
        let cleanName = districtName.lowercased().replacingOccurrences(of: " район", with: "").trimmingCharacters(in: .whitespaces)
        return activeDistricts.contains { d in
            let dClean = d.lowercased().replacingOccurrences(of: " район", with: "").trimmingCharacters(in: .whitespaces)
            return dClean == cleanName || dClean.contains(cleanName) || cleanName.contains(dClean)
        }
    }

    /// Колір заливки для конкретного району
    func districtColor(for districtName: String) -> Color {
        if isDistrictActive(districtName) {
            return .red
        } else if threatLevel != nil || !activeThreats.isEmpty {
            return self.color
        }
        return Color(red: 0.04, green: 0.14, blue: 0.38).opacity(0.32)
    }

    init(id: Int, name: String, isActive: Bool, level: Int, description: String, coordinate: CLLocationCoordinate2D, lastChanged: String? = nil, threatLevel: String? = nil, threatType: String? = nil, threatDetail: String? = nil) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.level = level
        self.description = description
        self.coordinate = coordinate
        self.lastChanged = lastChanged
        self._threatLevel = threatLevel
        self._threatType = threatType
        self._threatDetail = threatDetail
    }

    // Custom Codable conformance for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, name, isActive, level, description, lastChanged
        case latitude, longitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        level = try container.decode(Int.self, forKey: .level)
        description = try container.decode(String.self, forKey: .description)
        lastChanged = try container.decodeIfPresent(String.self, forKey: .lastChanged)

        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(level, forKey: .level)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(lastChanged, forKey: .lastChanged)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }
}
