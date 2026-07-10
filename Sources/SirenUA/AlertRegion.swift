import Foundation
import MapKit
import SwiftUI

struct AlertRegion: Identifiable, Codable, Equatable {
    static func == (lhs: AlertRegion, rhs: AlertRegion) -> Bool {
        return lhs.id == rhs.id
    }
    let id: Int
    let name: String
    var isActive: Bool
    var level: Int
    var description: String
    let coordinate: CLLocationCoordinate2D
    var lastChanged: String?
    var threatLevel: String?   // "none", "low", "medium", "high", "critical"
    var threatType: String?    // "mig31k", "shahed", "cruise_missile", etc
    var threatDetail: String?  // Опис загрози українською
    var threatConfidence: Int? // 0-100% AI confidence score
    var threatETA: String?     // "~20-40 хв" expected arrival time
    var isThreatPredictive: Bool = false // true if AI-predicted route
    var activeThreats: [SingleThreatInfo] = [] // Масив усіх активних загроз
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

    /// Кількість активних загроз різних типів
    var threatCount: Int { activeThreats.count }

    var icon: String {
        switch level {
        case 1: return "exclamationmark.triangle.fill"
        case 2: return "bell.fill"
        case 3: return "speaker.wave.3.fill"
        default: return "info.circle.fill"
        }
    }

    var color: Color {
        switch level {
        case 1: return .yellow
        case 2: return .orange
        case 3: return .red
        default: return .blue
        }
    }

    init(id: Int, name: String, isActive: Bool, level: Int, description: String, coordinate: CLLocationCoordinate2D, lastChanged: String? = nil, threatLevel: String? = nil, threatType: String? = nil, threatDetail: String? = nil) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.level = level
        self.description = description
        self.coordinate = coordinate
        self.lastChanged = lastChanged
        self.threatLevel = threatLevel
        self.threatType = threatType
        self.threatDetail = threatDetail
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
