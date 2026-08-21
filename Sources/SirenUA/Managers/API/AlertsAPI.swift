import Foundation
import OSLog

private let alertsLogger = Logger(subsystem: "com.sirenua", category: "AlertsAPI")

// MARK: - Live Alerts API

extension NetworkManager {

    /// Fetches the live air-raid alerts map from ubilling with up to 3 automatic retries.
    /// Returns a dictionary mapping Ukrainian region name → AerialAlertState.
    func fetchLiveAlerts(maxAttempts: Int = 3) async throws -> [String: AerialAlertState] {
        guard let url = URL(string: Self.alertsBaseURL) else {
            throw NetworkError.invalidURL(Self.alertsBaseURL)
        }

        let request = makeRequest(url: url, agent: Self.userAgent)
        alertsLogger.info("Fetching live alerts from \(Self.alertsBaseURL) (max \(maxAttempts) attempts)")

        var lastError: Error? = nil
        for attempt in 1...maxAttempts {
            do {
                let data = try await fetch(request: request)
                do {
                    let decoded = try JSONDecoder().decode(AerialAlertsResponse.self, from: data)
                    alertsLogger.info("Decoded \(decoded.states.count) region states on attempt \(attempt)")
                    return decoded.states
                } catch {
                    alertsLogger.error("Alert decoding failed: \(error.localizedDescription)")
                    throw NetworkError.decodingFailed(error)
                }
            } catch {
                if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                    throw error
                }
                lastError = error
                alertsLogger.warning("Attempt \(attempt)/\(maxAttempts) failed to fetch alerts: \(error.localizedDescription)")
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s backoff
                }
            }
        }

        if let lastError = lastError {
            throw lastError
        }
        throw NetworkError.invalidResponse(statusCode: nil)
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
