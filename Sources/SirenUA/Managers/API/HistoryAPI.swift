import Foundation
import OSLog

private let historyLogger = Logger(subsystem: "com.sirenua", category: "HistoryAPI")

// MARK: - Region History API (Premium)

extension NetworkManager {

    /// Fetches threat history for a specific region from the server.
    /// - Parameters:
    ///   - date: Optional date string in "yyyy-MM-dd" format. If nil, server defaults to today.
    func fetchRegionHistory(
        serverURL: String,
        region: String,
        date: String? = nil,
        limit: Int = 200
    ) async throws -> [RegionHistoryEvent] {
        let base = serverURL.hasSuffix("/") ? serverURL : "\(serverURL)/"
        let encoded = region.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? region
        var urlString = "\(base)api/history/\(encoded)?limit=\(limit)"
        if let date = date { urlString += "&date=\(date)" }

        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        var request = makeRequest(url: url, agent: Self.premiumAgent)
        request.timeoutInterval = 10.0
        historyLogger.info("Fetching history for \(region) date=\(date ?? "today")")

        let data = try await fetch(request: request)

        do {
            let decoded = try JSONDecoder().decode(RegionHistoryResponse.self, from: data)
            historyLogger.info("Fetched \(decoded.events.count) history events for \(region)")
            return decoded.events
        } catch {
            historyLogger.error("History decoding failed: \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }
}
