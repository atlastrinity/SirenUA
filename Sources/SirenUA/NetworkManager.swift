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
