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
    
    /// Formatted date for display
    var displayDate: String {
        // Server sends ISO format like "2026-07-07 14:23:00" in UTC
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        isoFormatter.locale = Locale(identifier: "uk_UA")
        
        if let date = isoFormatter.date(from: timestamp) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "uk_UA")
            displayFormatter.timeZone = TimeZone.current
            displayFormatter.dateFormat = "d MMM, HH:mm"
            return displayFormatter.string(from: date)
        }
        return timestamp
    }
    
    var displayTime: String {
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        if let date = isoFormatter.date(from: timestamp) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeZone = TimeZone.current
            timeFormatter.dateFormat = "HH:mm"
            return timeFormatter.string(from: date)
        }
        return ""
    }
    
    var displayDay: String {
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        isoFormatter.locale = Locale(identifier: "uk_UA")
        if let date = isoFormatter.date(from: timestamp) {
            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale(identifier: "uk_UA")
            dayFormatter.timeZone = TimeZone.current
            dayFormatter.dateFormat = "d MMMM yyyy"
            return dayFormatter.string(from: date)
        }
        return ""
    }
    
    /// Emoji icon for threat type
    var typeIcon: String {
        switch threat_type {
        case "official_alarm": return threat_level == "none" ? "🟢" : "🚨"
        case "shahed": return "🛩"
        case "cruise_missile": return "🚀"
        case "ballistic": return "💥"
        case "mig31k": return "✈️"
        case "kab": return "💣"
        case "iskander": return "🎯"
        case "tu95": return "✈️"
        default: return "⚠️"
        }
    }
    
    /// Human-readable threat type name
    var typeName: String {
        switch threat_type {
        case "official_alarm": return threat_level == "none" ? "Відбій тривоги" : "Повітряна тривога"
        case "shahed": return "БПЛА Шахед"
        case "cruise_missile": return "Крилаті ракети"
        case "ballistic": return "Балістика"
        case "mig31k": return "МіГ-31К (Кинджал)"
        case "kab": return "КАБ"
        case "iskander": return "Іскандер"
        case "tu95": return "Ту-95МС"
        default: return "Загроза з повітря"
        }
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
