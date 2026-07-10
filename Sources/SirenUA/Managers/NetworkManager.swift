import Foundation
import CoreLocation
import OSLog

private let networkLogger = Logger(subsystem: "com.sirenua", category: "Network")

// MARK: - NetworkManager
final class NetworkManager: Sendable {

    private static let alertsBaseURL  = "https://ubilling.net.ua/aerialalerts/"
    private static let userAgent      = "ios-sirenua/4.2"
    private static let premiumAgent   = "ios-sirenua-premium/4.2"
    private static let defaultTimeout: TimeInterval = 8.0

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Live Alerts

    /// Fetches the live air-raid alerts map  
    /// Returns a dictionary mapping Ukrainian region name → AerialAlertState
    func fetchLiveAlerts() async throws -> [String: AerialAlertState] {
        guard let url = URL(string: Self.alertsBaseURL) else {
            throw NetworkError.invalidURL(Self.alertsBaseURL)
        }

        let request = makeRequest(url: url, agent: Self.userAgent)
        networkLogger.info("Fetching live alerts from \(Self.alertsBaseURL)")

        let data = try await fetch(request: request)

        do {
            let decoded = try JSONDecoder().decode(AerialAlertsResponse.self, from: data)
            networkLogger.info("Decoded \(decoded.states.count) region states")
            return decoded.states
        } catch {
            networkLogger.error("Alert decoding failed: \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }

    // MARK: - Threats (Premium)

    /// Fetches threat levels from the threat-monitoring server (Premium feature)
    func fetchThreats(serverURL: String) async throws -> [String: ThreatInfo] {
        let base = serverURL.hasSuffix("/") ? serverURL : "\(serverURL)/"
        let urlString = "\(base)api/threats"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        var request = makeRequest(url: url, agent: Self.premiumAgent)
        request.timeoutInterval = 5.0   // faster timeout for threat server
        networkLogger.info("Fetching threats from \(urlString)")

        let data = try await fetch(request: request)

        do {
            let decoded = try JSONDecoder().decode(ThreatResponse.self, from: data)
            networkLogger.info("Decoded threats for \(decoded.threats.count) regions")
            return decoded.threats
        } catch {
            networkLogger.error("Threat decoding failed: \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }

    // MARK: - Helpers

    private func makeRequest(url: URL, agent: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(agent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = Self.defaultTimeout
        return request
    }

    private func fetch(request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse(statusCode: nil)
        }
        guard (200...299).contains(http.statusCode) else {
            networkLogger.warning("HTTP \(http.statusCode) from \(request.url?.absoluteString ?? "?")")
            throw NetworkError.invalidResponse(statusCode: http.statusCode)
        }
        return data
    }

    // MARK: - Shelters

    /// Fetches nearby shelters from the threat-monitoring server (uses OSM data)
    func fetchShelters(serverURL: String, lat: Double, lon: Double, radiusMeters: Double) async throws -> [ShelterItem] {
        let base = serverURL.hasSuffix("/") ? serverURL : "\(serverURL)/"
        let urlString = "\(base)api/shelters?lat=\(lat)&lon=\(lon)&radius=\(Int(radiusMeters))&limit=50"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        var request = makeRequest(url: url, agent: Self.userAgent)
        request.timeoutInterval = 10.0  // shelter DB might be slower on first load
        networkLogger.info("Fetching shelters from \(urlString)")

        let data = try await fetch(request: request)

        do {
            let decoded = try JSONDecoder().decode(ShelterResponse.self, from: data)
            networkLogger.info("Found \(decoded.count) shelters within \(Int(radiusMeters))m (DB total: \(decoded.total_in_db))")
            return decoded.shelters
        } catch {
            networkLogger.error("Shelter decoding failed: \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }

    // MARK: - Region History (Premium)

    /// Fetches threat history for a specific region from the server
    /// - Parameters:
    ///   - date: Optional date string in "yyyy-MM-dd" format. If nil, server defaults to today.
    func fetchRegionHistory(serverURL: String, region: String, date: String? = nil, limit: Int = 200) async throws -> [RegionHistoryEvent] {
        let base = serverURL.hasSuffix("/") ? serverURL : "\(serverURL)/"
        let encoded = region.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? region
        var urlString = "\(base)api/history/\(encoded)?limit=\(limit)"
        if let date = date {
            urlString += "&date=\(date)"
        }
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        var request = makeRequest(url: url, agent: Self.premiumAgent)
        request.timeoutInterval = 10.0
        networkLogger.info("Fetching history for \(region) date=\(date ?? "today")")

        let data = try await fetch(request: request)

        do {
            let decoded = try JSONDecoder().decode(RegionHistoryResponse.self, from: data)
            networkLogger.info("Fetched \(decoded.events.count) history events for \(region)")
            return decoded.events
        } catch {
            networkLogger.error("History decoding failed: \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }
}
// MARK: - Response Models

struct AerialAlertsResponse: Codable {
    let source: String
    let cachedat: String
    let states: [String: AerialAlertState]
}

struct AerialAlertState: Codable {
    let alertnow: Bool
    let changed: String
}

// MARK: - Threat Models (Premium)

struct ThreatResponse: Codable {
    let updated_at: String
    let threats: [String: ThreatInfo]
}

struct SingleThreatInfo: Codable, Identifiable, Equatable {
    let threat_id: String
    let level: String
    let type: String?
    let detail: String?
    let since: String?
    let confidence: Int?
    let eta: String?
    let is_predictive: Bool?
    let is_test: Bool?
    let group_id: String?

    var id: String { threat_id }

    /// Іконка типу загрози для міні-картки
    var threatIcon: String {
        switch type {
        case "shahed":         return "airplane"
        case "cruise_missile": return "bolt.fill"
        case "ballistic":      return "arrow.up.right"
        case "mig31k":         return "jet.fill" // SF Symbol fallback
        case "kab":            return "flame.fill"
        case "tu95":           return "airplane.circle.fill"
        case "iskander":       return "arrow.up.right.circle.fill"
        case "artillery":      return "burst.fill"
        default:               return "exclamationmark.triangle.fill"
        }
    }

    /// Назва типу загрози українською
    var threatLabel: String {
        switch type {
        case "shahed":         return "БПЛА"
        case "cruise_missile": return "Ракети"
        case "ballistic":      return "Балістика"
        case "mig31k":         return "МіГ-31К"
        case "kab":            return "КАБ"
        case "tu95":           return "Ту-95"
        case "iskander":       return "Іскандер"
        case "artillery":      return "Обстріл"
        default:               return "Загроза"
        }
    }

    /// Обчислена дата виявлення загрози з ISO8601
    var sinceDate: Date? {
        guard let since = since else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: since) {
            return date
        }
        // Спроба без мікросекунд
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: since) {
            return date
        }
        // Спроба для звичайного формату YYYY-MM-DD HH:MM:SS
        let customFormatter = DateFormatter()
        customFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        customFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return customFormatter.date(from: since)
    }

    /// Скільки хвилин пройшло з моменту виявлення загрози
    var elapsedMinutes: Int {
        guard let date = sinceDate else { return 0 }
        return Int(Date().timeIntervalSince(date) / 60)
    }

    /// Динамічний час прибуття (ETA), перерахований відносно поточного часу
    var dynamicETA: String? {
        guard let eta = eta, !eta.isEmpty else {
            // Якщо ETA не задано, повертаємо час виявлення
            let minAgo = elapsedMinutes
            if minAgo <= 0 {
                return "щойно"
            } else if minAgo < 60 {
                return "\(minAgo) хв тому"
            } else {
                let hr = minAgo / 60
                let mn = minAgo % 60
                return "\(hr) год \(mn) хв тому"
            }
        }
        
        let elapsed = elapsedMinutes
        
        // Очищаємо рядок ETA від зайвих символів
        let cleanEta = eta.replacingOccurrences(of: "~", with: "")
                          .replacingOccurrences(of: "+", with: "")
                          .trimmingCharacters(in: .whitespacesAndNewlines)
                          
        if cleanEta.hasSuffix("хв") {
            let valPart = cleanEta.replacingOccurrences(of: "хв", with: "").trimmingCharacters(in: .whitespaces)
            if valPart.contains("-") {
                let components = valPart.components(separatedBy: "-")
                if components.count == 2, let minVal = Int(components[0].trimmingCharacters(in: .whitespaces)), let maxVal = Int(components[1].trimmingCharacters(in: .whitespaces)) {
                    let newMin = max(0, minVal - elapsed)
                    let newMax = max(0, maxVal - elapsed)
                    if newMax == 0 {
                        return "в області"
                    } else if newMin == 0 {
                        return "~до \(newMax) хв"
                    } else {
                        return "~\(newMin)-\(newMax) хв"
                    }
                }
            } else if let minutes = Int(valPart) {
                let remaining = minutes - elapsed
                if remaining <= 0 {
                    return "в області"
                } else {
                    return "~\(remaining) хв"
                }
            }
        } else if cleanEta.hasSuffix("год") {
            let valPart = cleanEta.replacingOccurrences(of: "год", with: "").trimmingCharacters(in: .whitespaces)
            if valPart.contains("-") {
                let components = valPart.components(separatedBy: "-")
                if components.count == 2, let minVal = Double(components[0].trimmingCharacters(in: .whitespaces)), let maxVal = Double(components[1].trimmingCharacters(in: .whitespaces)) {
                    let minMin = Int(minVal * 60)
                    let maxMin = Int(maxVal * 60)
                    let newMin = max(0, minMin - elapsed)
                    let newMax = max(0, maxMin - elapsed)
                    if newMax == 0 {
                        return "в області"
                    } else {
                        let newMinHr = Double(newMin) / 60.0
                        let newMaxHr = Double(newMax) / 60.0
                        if newMin == 0 {
                            return String(format: "~до %.1f год", newMaxHr)
                        } else {
                            return String(format: "~%.1f-%.1f год", newMinHr, newMaxHr)
                        }
                    }
                }
            } else if let hours = Double(valPart) {
                let remainingMin = Int(hours * 60) - elapsed
                if remainingMin <= 0 {
                    return "в області"
                } else {
                    let remainingHr = Double(remainingMin) / 60.0
                    return String(format: "~%.1f-%.1f год", remainingHr, remainingHr) // Safe fallback
                }
            }
        }
        
        return eta
    }

    /// Форматований час виявлення (київський час)
    var detectionTimeString: String {
        guard let date = sinceDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/Kyiv")
        return formatter.string(from: date)
    }

    /// Час виявлення + скільки часу тому (наприклад: "19:20 (12 хв тому)")
    var formattedSince: String {
        let timeStr = detectionTimeString
        let elapsed = elapsedMinutes
        if elapsed <= 0 {
            return "\(timeStr) (щойно)"
        } else if elapsed < 60 {
            return "\(timeStr) (\(elapsed) хв тому)"
        } else {
            let hr = elapsed / 60
            let mn = elapsed % 60
            return "\(timeStr) (\(hr) год \(mn) хв тому)"
        }
    }

    /// Обчислює динамічну відстань на основі початкового значення, ETA та минулого часу
    func dynamicDistance(from originalLine: String) -> String {
        // Очікуваний шаблон: "Відстань: ~120 км" або "Відстань до цілі: ~250 км"
        // Очищаємо від службових слів для безпечнішого пошуку чисел
        let cleanLine = originalLine.replacingOccurrences(of: "~", with: "")
                                    .replacingOccurrences(of: "до цілі:", with: "")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Знаходимо перше число в рядку (відстань в км)
        guard let numRange = cleanLine.range(of: "\\d+", options: .regularExpression),
              let originalDistance = Double(cleanLine[numRange]) else {
            return originalLine
        }
        
        // Отримуємо початковий ETA у хвилинах
        guard let initialETA = eta, !initialETA.isEmpty else {
            // Якщо початкового ETA немає, робимо спрощений спад в залежності від типу цілі
            let elapsed = elapsedMinutes
            let speed: Double = (type?.lowercased() == "ballistics" || type?.lowercased() == "kinzhal") ? 60.0 : 2.5 // км/хв
            let remainingDist = max(0, originalDistance - speed * Double(elapsed))
            
            let originalDigits = String(format: "%.0f", originalDistance)
            let remainingDigits = String(format: "%.0f", remainingDist)
            return originalLine.replacingOccurrences(of: originalDigits, with: remainingDigits)
        }
        
        // Парсимо початковий ETA у хвилинах
        let cleanEta = initialETA.replacingOccurrences(of: "~", with: "")
                                 .replacingOccurrences(of: "+", with: "")
                                 .trimmingCharacters(in: .whitespacesAndNewlines)
                                 
        var initialETAMinutes: Double = 0
        if cleanEta.hasSuffix("хв") {
            let valPart = cleanEta.replacingOccurrences(of: "хв", with: "").trimmingCharacters(in: .whitespaces)
            if valPart.contains("-") {
                let components = valPart.components(separatedBy: "-")
                if components.count == 2, let maxVal = Double(components[1].trimmingCharacters(in: .whitespaces)) {
                    initialETAMinutes = maxVal
                }
            } else if let minutes = Double(valPart) {
                initialETAMinutes = minutes
            }
        } else if cleanEta.hasSuffix("год") {
            let valPart = cleanEta.replacingOccurrences(of: "год", with: "").trimmingCharacters(in: .whitespaces)
            if valPart.contains("-") {
                let components = valPart.components(separatedBy: "-")
                if components.count == 2, let maxVal = Double(components[1].trimmingCharacters(in: .whitespaces)) {
                    initialETAMinutes = maxVal * 60.0
                }
            } else if let hours = Double(valPart) {
                initialETAMinutes = hours * 60.0
            }
        }
        
        guard initialETAMinutes > 0 else {
            return originalLine
        }
        
        let elapsed = Double(elapsedMinutes)
        let speed = originalDistance / initialETAMinutes
        let remainingDistance = max(0, originalDistance - speed * elapsed)
        
        let originalDigits = String(format: "%.0f", originalDistance)
        let remainingDigits = String(format: "%.0f", remainingDistance)
        
        return originalLine.replacingOccurrences(of: originalDigits, with: remainingDigits)
    }
}

struct ThreatInfo: Codable {
    let level: String       // "none" | "low" | "medium" | "high" | "critical"
    let type: String?
    let detail: String?
    let since: String?
    let confidence: Int?    // 0-100% AI confidence score
    let eta: String?        // "~20-40 хв" expected arrival time
    let is_predictive: Bool? // true if AI-predicted (not confirmed)
    let is_active: Bool?     // true if official air alarm is active
    let active_threats: [SingleThreatInfo]?  // Масив усіх активних загроз
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidURL(String)
    case invalidResponse(statusCode: Int?)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Невірна URL: \(url)"
        case .invalidResponse(let code):
            if let code { return "Сервер повернув помилку \(code)" }
            return "Невірна відповідь від сервера"
        case .decodingFailed(let err):
            return "Помилка декодування даних: \(err.localizedDescription)"
        }
    }
}

// Legacy alias — keeps old call sites compiling
extension NetworkError {
    static var invalidURL: NetworkError { .invalidURL("unknown") }
    static var invalidResponse: NetworkError { .invalidResponse(statusCode: nil) }
}
