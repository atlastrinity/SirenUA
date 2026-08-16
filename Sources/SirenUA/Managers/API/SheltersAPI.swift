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

    /// Fetches all shelters for a specific region (oblast) from the threat-monitoring server.
    func fetchSheltersByRegion(serverURL: String, region: String) async throws -> [ShelterItem] {
        let base = serverURL.hasSuffix("/") ? serverURL : "\(serverURL)/"
        guard let encodedRegion = region.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw NetworkError.invalidURL(region)
        }
        let urlString = "\(base)api/shelters/by_region?region=\(encodedRegion)"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        var request = makeRequest(url: url, agent: Self.userAgent)
        request.timeoutInterval = 10.0
        sheltersLogger.info("Fetching regional shelters from \(urlString)")

        let data = try await fetch(request: request)
        do {
            let decoded = try JSONDecoder().decode(ShelterResponse.self, from: data)
            sheltersLogger.info("Found \(decoded.count) shelters for region \(region)")
            return decoded.shelters
        } catch {
            sheltersLogger.error("Regional shelter decoding failed: \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }

    /// Searches shelters by text query (city name, street, shelter name) with optional region filter.
    func searchShelters(
        serverURL: String,
        query: String = "",
        region: String? = nil,
        onlyPrimary: Bool = false,
        limit: Int = 50
    ) async throws -> [ShelterItem] {
        let base = serverURL.hasSuffix("/") ? serverURL : "\(serverURL)/"
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "only_primary", value: onlyPrimary ? "true" : "false"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let region = region, !region.isEmpty {
            queryItems.append(URLQueryItem(name: "region", value: region))
        }

        var components = URLComponents(string: "\(base)api/shelters/search")
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidURL("\(base)api/shelters/search")
        }

        var request = makeRequest(url: url, agent: Self.userAgent)
        request.timeoutInterval = 10.0
        sheltersLogger.info("Searching shelters with query '\(query)' region '\(region ?? "all")'")

        let data = try await fetch(request: request)
        do {
            let decoded = try JSONDecoder().decode(ShelterResponse.self, from: data)
            sheltersLogger.info("Search returned \(decoded.count) shelters")
            return decoded.shelters
        } catch {
            sheltersLogger.error("Shelter search decoding failed: \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }

    /// Fetches summary statistics and centroid coordinates for all 26 Ukrainian regions.
    func fetchShelterRegions(serverURL: String) async throws -> [ShelterRegionSummary] {
        let base = serverURL.hasSuffix("/") ? serverURL : "\(serverURL)/"
        let urlString = "\(base)api/shelters/regions"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        var request = makeRequest(url: url, agent: Self.userAgent)
        request.timeoutInterval = 10.0
        sheltersLogger.info("Fetching shelter regions list from \(urlString)")

        let data = try await fetch(request: request)
        do {
            let decoded = try JSONDecoder().decode(ShelterRegionsResponse.self, from: data)
            sheltersLogger.info("Loaded \(decoded.regions.count) regions summary (total shelters: \(decoded.total_shelters))")
            return decoded.regions
        } catch {
            sheltersLogger.error("Shelter regions decoding failed: \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }
}
