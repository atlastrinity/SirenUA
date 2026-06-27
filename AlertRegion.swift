import Foundation
import MapKit
import SwiftUI

@available(iOS 17.0, *)
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

    init(id: Int, name: String, isActive: Bool, level: Int, description: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.level = level
        self.description = description
        self.coordinate = coordinate
    }

    // Custom Codable conformance for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, name, isActive, level, description
        case latitude, longitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        level = try container.decode(Int.self, forKey: .level)
        description = try container.decode(String.self, forKey: .description)

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
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }
}
