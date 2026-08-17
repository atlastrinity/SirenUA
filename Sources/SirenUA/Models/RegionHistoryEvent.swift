import Foundation

/// Подія з хронології загроз для області
struct RegionHistoryEvent: Identifiable, Codable {
    let serverId: Int
    let timestamp: String
    let threat_level: String
    let threat_type: String?
    let detail: String?
    let confidence: Int?
    
    var id: String {
        "\(serverId)_\(timestamp)_\(threat_level)"
    }
    
    enum CodingKeys: String, CodingKey {
        case serverId = "id"
        case timestamp, threat_level, threat_type, detail, confidence
    }
    
    init(serverId: Int, timestamp: String, threat_level: String, threat_type: String? = nil, detail: String? = nil, confidence: Int? = nil) {
        self.serverId = serverId
        self.timestamp = timestamp
        self.threat_level = threat_level
        self.threat_type = threat_type
        self.detail = detail
        self.confidence = confidence
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idInt = try? container.decode(Int.self, forKey: .serverId) {
            self.serverId = idInt
        } else if let idStr = try? container.decode(String.self, forKey: .serverId), let idInt = Int(idStr) {
            self.serverId = idInt
        } else {
            self.serverId = Int.random(in: 100000...999999)
        }
        
        self.timestamp = (try? container.decode(String.self, forKey: .timestamp)) ?? ""
        self.threat_level = (try? container.decode(String.self, forKey: .threat_level)) ?? "none"
        self.threat_type = try? container.decodeIfPresent(String.self, forKey: .threat_type)
        self.detail = try? container.decodeIfPresent(String.self, forKey: .detail)
        self.confidence = try? container.decodeIfPresent(Int.self, forKey: .confidence)
    }
    
    // MARK: - Static Date Formatter Cache Pool

    private enum DateCache {
        static let isoFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm:ss"
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.locale = Locale(identifier: "uk_UA")
            return f
        }()

        static let displayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "uk_UA")
            f.timeZone = TimeZone.current
            f.dateFormat = "d MMM, HH:mm"
            return f
        }()

        static let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.timeZone = TimeZone.current
            f.dateFormat = "HH:mm"
            return f
        }()

        static let dayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "uk_UA")
            f.timeZone = TimeZone.current
            f.dateFormat = "d MMMM yyyy"
            return f
        }()
    }

    /// Formatted date for display
    var displayDate: String {
        if let date = DateCache.isoFormatter.date(from: timestamp) {
            return DateCache.displayFormatter.string(from: date)
        }
        return timestamp
    }
    
    var displayTime: String {
        if let date = DateCache.isoFormatter.date(from: timestamp) {
            return DateCache.timeFormatter.string(from: date)
        }
        return ""
    }
    
    var displayDay: String {
        if let date = DateCache.isoFormatter.date(from: timestamp) {
            return DateCache.dayFormatter.string(from: date)
        }
        return ""
    }
    
    /// Emoji icon for threat type
    var typeIcon: String {
        let isClear = (threat_level == "none" || threat_level == "clear")
        if isClear {
            return "🟢"
        }
        return ThreatConstants.emoji(for: threat_type)
    }
    
    /// Human-readable threat type name
    var typeName: String {
        let isClear = (threat_level == "none" || threat_level == "clear")
        if isClear {
            return ThreatConstants.clearTitle(for: threat_type, detail: detail)
        }
        return ThreatConstants.title(for: threat_type)
    }
}

/// Server response for region history
struct RegionHistoryResponse: Decodable {
    let region: String?
    let count: Int?
    let events: [RegionHistoryEvent]
    
    enum CodingKeys: String, CodingKey {
        case region, count, events, history
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.region = try? container.decodeIfPresent(String.self, forKey: .region)
        self.count = try? container.decodeIfPresent(Int.self, forKey: .count)
        
        let eventsFromEvents = try? container.decodeIfPresent([RegionHistoryEvent].self, forKey: .events)
        let eventsFromHistory = try? container.decodeIfPresent([RegionHistoryEvent].self, forKey: .history)
        
        self.events = eventsFromEvents ?? eventsFromHistory ?? []
    }
}
