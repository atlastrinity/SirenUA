import Foundation
import CoreLocation

@available(iOS 17.0, *)
class NetworkManager {
    private let baseURL = "https://alerts.in.ua/api"

    func fetchAlerts() async throws -> [AlertRegion] {
        guard let url = URL(string: "\(baseURL)/air-raid") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios-sirenua", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }

        // Parse response
        if let alertData = try? JSONDecoder().decode(AlertResponse.self, from: data) {
            return alertData.states.map { alertState in
                AlertRegion(
                    id: alertState.id,
                    name: alertState.name,
                    isActive: alertState.state == "alert",
                    level: Int.random(in: 1...4),
                    description: alertState.description ?? "No description",
                    coordinate: CLLocationCoordinate2D(latitude: 50.0 + Double.random(in: -10...10),
                                                     longitude: 30.0 + Double.random(in: -20...20))
                )
            }
        }

        throw NetworkError.invalidResponse
    }
}

@available(iOS 17.0, *)
struct AlertResponse: Codable {
    let states: [AlertState]
    let last_update: String

    struct AlertState: Codable {
        let id: Int
        let name: String
        let state: String
        let description: String?
    }
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
