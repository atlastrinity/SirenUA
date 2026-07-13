import Foundation
import OSLog

private let alertsLogger = Logger(subsystem: "com.sirenua", category: "AlertsAPI")

// MARK: - Live Alerts API

extension NetworkManager {

    /// Fetches the live air-raid alerts map from ubilling.
    /// Returns a dictionary mapping Ukrainian region name → AerialAlertState.
    func fetchLiveAlerts() async throws -> [String: AerialAlertState] {
        guard let url = URL(string: Self.alertsBaseURL) else {
            throw NetworkError.invalidURL(Self.alertsBaseURL)
        }

        let request = makeRequest(url: url, agent: Self.userAgent)
        alertsLogger.info("Fetching live alerts from \(Self.alertsBaseURL)")

        let data = try await fetch(request: request)

        do {
            let decoded = try JSONDecoder().decode(AerialAlertsResponse.self, from: data)
            alertsLogger.info("Decoded \(decoded.states.count) region states")
            return decoded.states
        } catch {
            alertsLogger.error("Alert decoding failed: \(error.localizedDescription)")
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
