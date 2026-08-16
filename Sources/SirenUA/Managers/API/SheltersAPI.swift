import Foundation
import OSLog

private let sheltersLogger = Logger(subsystem: "com.sirenua", category: "SheltersAPI")

// MARK: - Shelters API

extension NetworkManager {

    /// Fetches nearby shelters from the threat-monitoring server (uses OSM data).
    func fetchShelters(serverURL: String, lat: Double, lon: Double, radiusMeters: Double) async throws -> [ShelterItem] {
        let base = serverURL.hasSuffix("/") ? serverURL : "\(serverURL)/"
        let urlString = "\(base)api/shelters?lat=\(lat)&lon=\(lon)&radius=\(Int(radiusMeters))&limit=50"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        var request = makeRequest(url: url, agent: Self.userAgent)
        request.timeoutInterval = 10.0  // shelter DB might be slower on first load
        sheltersLogger.info("Fetching shelters from \(urlString)")

        let data = try await fetch(request: request)

        do {
            let decoded = try JSONDecoder().decode(ShelterResponse.self, from: data)
            sheltersLogger.info("Found \(decoded.count) shelters within \(Int(radiusMeters))m (DB total: \(decoded.total_in_db ?? 0))")
            return decoded.shelters
        } catch {
            sheltersLogger.error("Shelter decoding failed: \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }
}
