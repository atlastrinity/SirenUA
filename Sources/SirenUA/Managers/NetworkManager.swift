import Foundation
import CoreLocation
import OSLog

private let networkLogger = Logger(subsystem: "com.sirenua", category: "Network")

// MARK: - NetworkManager
// API method extensions live in Managers/API/:
//   AlertsAPI.swift   — fetchLiveAlerts(), AerialAlertsResponse, AerialAlertState
//   ThreatsAPI.swift  — fetchThreats(serverURL:), ThreatResponse, ThreatInfo, SingleThreatInfo
//   SheltersAPI.swift — fetchShelters(serverURL:lat:lon:radiusMeters:)
//   HistoryAPI.swift  — fetchRegionHistory(serverURL:region:date:limit:)

final class NetworkManager: Sendable {

    static var serverURL: String {
        return "http://localhost:8085"
    }
    static let alertsBaseURL  = "https://ubilling.net.ua/aerialalerts/"
    static let userAgent      = "ios-sirenua/4.2"
    static let premiumAgent   = "ios-sirenua-premium/4.2"
    static let defaultTimeout: TimeInterval = 8.0

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Core Utilities (used by all API extensions)

    func makeRequest(url: URL, agent: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(agent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = Self.defaultTimeout
        return request
    }

    func fetch(request: URLRequest) async throws -> Data {
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

// Legacy convenience aliases — keeps old call sites compiling
extension NetworkError {
    static var invalidURL: NetworkError { .invalidURL("unknown") }
    static var invalidResponse: NetworkError { .invalidResponse(statusCode: nil) }
}
