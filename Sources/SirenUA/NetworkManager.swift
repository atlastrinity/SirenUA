import Foundation
import CoreLocation

@available(iOS 17.0, *)
class NetworkManager {
    private let baseURL = "https://ubilling.net.ua/aerialalerts/"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches the live alerts and returns a dictionary mapping Region Name to AerialAlertState
    func fetchLiveAlerts() async throws -> [String: AerialAlertState] {
        guard let url = URL(string: baseURL) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios-sirenua", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }

        do {
            let alertData = try JSONDecoder().decode(AerialAlertsResponse.self, from: data)
            return alertData.states
        } catch {
            print("DECODING ERROR: \(error)")
            throw NetworkError.invalidResponse
        }
    }
    
    /// Fetches threat levels from the local threat monitoring server (Premium feature)
    func fetchThreats(serverURL: String) async throws -> [String: ThreatInfo] {
        let urlString = serverURL.hasSuffix("/") ? "\(serverURL)api/threats" : "\(serverURL)/api/threats"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios-sirenua-premium", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 5 // Швидкий таймаут для локального сервера
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        let threatData = try JSONDecoder().decode(ThreatResponse.self, from: data)
        return threatData.threats
    }
}

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

struct ThreatInfo: Codable {
    let level: String       // "none", "low", "medium", "high", "critical"
    let type: String?
    let detail: String?
    let since: String?
}

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

