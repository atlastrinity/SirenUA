import SwiftUI
import Foundation
import MapKit
import OSLog

private let threatsLogger = Logger(subsystem: "com.sirenua", category: "ThreatsAPI")

// MARK: - Threats API (Premium)

extension NetworkManager {

    /// Fetches threat levels from the threat-monitoring server (Premium feature).
    func fetchThreats(serverURL: String) async throws -> [String: ThreatInfo] {
        let base = serverURL.hasSuffix("/") ? serverURL : "\(serverURL)/"
        let urlString = "\(base)api/threats"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL(urlString)
        }

        var request = makeRequest(url: url, agent: Self.premiumAgent)
        request.timeoutInterval = 30.0   // 30s timeout to allow Render cold starts and cellular latency
        threatsLogger.info("Fetching threats from \(urlString)")

        let data = try await fetch(request: request)

        do {
            if let decoded = try? JSONDecoder().decode(ThreatResponse.self, from: data) {
                threatsLogger.info("Decoded wrapped threats for \(decoded.threats.count) regions")
                return decoded.threats
            }
            let directDict = try JSONDecoder().decode([String: ThreatInfo].self, from: data)
            threatsLogger.info("Decoded threats dict for \(directDict.count) regions")
            return directDict
        } catch {
            threatsLogger.error("Threat decoding failed: \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }
}

// MARK: - Threat Models

struct ThreatResponse: Codable {
    let updated_at: String
    let threats: [String: ThreatInfo]
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

// MARK: - SingleThreatInfo

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
    let origin_latitude: Double?
    let origin_longitude: Double?
    let transit_from: String?

    let last_checkpoint_latitude: Double?
    let last_checkpoint_longitude: Double?

    // MARK: - Tactical Aviation Profile
    let carrier_type: String?
    let carrier_origin_name: String?
    let carrier_origin_latitude: Double?
    let carrier_origin_longitude: Double?
    let launch_sector_name: String?
    let launch_sector_latitude: Double?
    let launch_sector_longitude: Double?

    init(
        threat_id: String,
        level: String,
        type: String? = nil,
        detail: String? = nil,
        since: String? = nil,
        confidence: Int? = nil,
        eta: String? = nil,
        is_predictive: Bool? = nil,
        is_test: Bool? = nil,
        group_id: String? = nil,
        origin_latitude: Double? = nil,
        origin_longitude: Double? = nil,
        transit_from: String? = nil,
        last_checkpoint_latitude: Double? = nil,
        last_checkpoint_longitude: Double? = nil,
        carrier_type: String? = nil,
        carrier_origin_name: String? = nil,
        carrier_origin_latitude: Double? = nil,
        carrier_origin_longitude: Double? = nil,
        launch_sector_name: String? = nil,
        launch_sector_latitude: Double? = nil,
        launch_sector_longitude: Double? = nil
    ) {
        self.threat_id = threat_id
        self.level = level
        self.type = type
        self.detail = detail
        self.since = since
        self.confidence = confidence
        self.eta = eta
        self.is_predictive = is_predictive
        self.is_test = is_test
        self.group_id = group_id
        self.origin_latitude = origin_latitude
        self.origin_longitude = origin_longitude
        self.transit_from = transit_from
        self.last_checkpoint_latitude = last_checkpoint_latitude
        self.last_checkpoint_longitude = last_checkpoint_longitude
        self.carrier_type = carrier_type
        self.carrier_origin_name = carrier_origin_name
        self.carrier_origin_latitude = carrier_origin_latitude
        self.carrier_origin_longitude = carrier_origin_longitude
        self.launch_sector_name = launch_sector_name
        self.launch_sector_latitude = launch_sector_latitude
        self.launch_sector_longitude = launch_sector_longitude
    }

    var id: String { threat_id }

    var originCoordinate: CLLocationCoordinate2D? {
        if let lat = origin_latitude, let lon = origin_longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        if let lat = launch_sector_latitude, let lon = launch_sector_longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        if let transit = transit_from, let coord = RegionRegistry.regionalCoordinates[transit] {
            return coord
        }
        return nil
    }

    var carrierOriginCoordinate: CLLocationCoordinate2D? {
        guard let lat = carrier_origin_latitude, let lon = carrier_origin_longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var launchSectorCoordinate: CLLocationCoordinate2D? {
        guard let lat = launch_sector_latitude, let lon = launch_sector_longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var lastCheckpointCoordinate: CLLocationCoordinate2D? {
        guard let lat = last_checkpoint_latitude, let lon = last_checkpoint_longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Іконка типу загрози з центрального реєстру ThreatConstants
    var threatIcon: String {
        ThreatConstants.sfSymbol(for: type)
    }

    /// Назва типу загрози з центрального реєстру ThreatConstants
    var threatLabel: String {
        ThreatConstants.title(for: type)
    }

    /// Колір типу загрози з центрального реєстру ThreatConstants
    var threatColor: Color {
        ThreatConstants.color(for: type)
    }

    // MARK: Time helpers

    var sinceDate: Date? {
        guard let since = since else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: since) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: since) { return date }
        let customFormatter = DateFormatter()
        customFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        customFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return customFormatter.date(from: since)
    }

    var elapsedMinutes: Int {
        guard let date = sinceDate else { return 0 }
        return Int(Date().timeIntervalSince(date) / 60)
    }

    var detectionTimeString: String {
        guard let date = sinceDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/Kyiv")
        return formatter.string(from: date)
    }

    var formattedSince: String {
        let timeStr = detectionTimeString
        let elapsed = elapsedMinutes
        if elapsed <= 0 {
            return "\(timeStr) (щойно)"
        } else if elapsed < 60 {
            return "\(timeStr) (\(elapsed) хв тому)"
        } else {
            let hr = elapsed / 60; let mn = elapsed % 60
            return "\(timeStr) (\(hr) год \(mn) хв тому)"
        }
    }

    var dynamicETA: String? {
        guard let eta = eta, !eta.isEmpty else {
            let minAgo = elapsedMinutes
            if minAgo <= 0 { return "щойно" }
            else if minAgo < 60 { return "\(minAgo) хв тому" }
            else { let hr = minAgo / 60; let mn = minAgo % 60; return "\(hr) год \(mn) хв тому" }
        }

        let elapsed = elapsedMinutes
        let cleanEta = eta.replacingOccurrences(of: "~", with: "")
                          .replacingOccurrences(of: "+", with: "")
                          .replacingOccurrences(of: "до", with: "")
                          .trimmingCharacters(in: .whitespacesAndNewlines)

        // Допоміжна функція для уніфікованого форматування залишку часу ("до X хв", "до X год Y хв", "в області")
        func formatRemaining(minutes: Int) -> String {
            if minutes <= 0 {
                return "в області"
            } else if minutes < 60 {
                return "до \(minutes) хв"
            } else {
                let hr = minutes / 60
                let mn = minutes % 60
                return mn == 0 ? "до \(hr) год" : "до \(hr) год \(mn) хв"
            }
        }

        // Case 1: Складений формат, наприклад "1 год 16 хв" або "1 год 45 хв"
        if cleanEta.contains("год") && cleanEta.contains("хв") {
            let parts = cleanEta.components(separatedBy: "год")
            if parts.count == 2,
               let hr = Int(parts[0].trimmingCharacters(in: .whitespaces)),
               let mn = Int(parts[1].replacingOccurrences(of: "хв", with: "").trimmingCharacters(in: .whitespaces)) {
                let totalMins = hr * 60 + mn
                return formatRemaining(minutes: totalMins - elapsed)
            }
        }

        // Case 2: Хвилини (діапазони "34-38 хв", "3-5 хв" або одинарні "16 хв", "45 хв")
        if cleanEta.hasSuffix("хв") {
            let valPart = cleanEta.replacingOccurrences(of: "хв", with: "").trimmingCharacters(in: .whitespaces)
            if valPart.contains("-") {
                let comps = valPart.components(separatedBy: "-")
                if comps.count == 2,
                   let maxVal = Int(comps[1].trimmingCharacters(in: .whitespaces)) {
                    // Уніфіковано беремо верхню безпечну межу діапазону мінус час польоту
                    return formatRemaining(minutes: maxVal - elapsed)
                }
            } else if let minutes = Int(valPart) {
                return formatRemaining(minutes: minutes - elapsed)
            }
        } else if cleanEta.hasSuffix("год") {
            let valPart = cleanEta.replacingOccurrences(of: "год", with: "").trimmingCharacters(in: .whitespaces)
            if valPart.contains("-") {
                let comps = valPart.components(separatedBy: "-")
                if comps.count == 2,
                   let maxVal = Double(comps[1].trimmingCharacters(in: .whitespaces)) {
                    let totalMins = Int(maxVal * 60)
                    return formatRemaining(minutes: totalMins - elapsed)
                }
            } else if let hours = Double(valPart) {
                let totalMins = Int(hours * 60)
                return formatRemaining(minutes: totalMins - elapsed)
            }
        }

        // Fallback: якщо просто число
        if let num = Int(cleanEta) {
            return formatRemaining(minutes: num - elapsed)
        }

        return eta
    }

    func dynamicDistance(from originalLine: String) -> String {
        let cleanLine = originalLine.replacingOccurrences(of: "~", with: "")
                                    .replacingOccurrences(of: "до цілі:", with: "")
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let numRange = cleanLine.range(of: "\\d+", options: .regularExpression),
              let originalDistance = Double(cleanLine[numRange]) else { return originalLine }

        let elapsed = Double(elapsedMinutes)
        let remainingDistance: Double

        if let initialETA = eta, !initialETA.isEmpty {
            let cleanEta = initialETA.replacingOccurrences(of: "~", with: "")
                                     .replacingOccurrences(of: "+", with: "")
                                     .trimmingCharacters(in: .whitespacesAndNewlines)
            var initialETAMinutes: Double = 0
            if cleanEta.hasSuffix("хв") {
                let val = cleanEta.replacingOccurrences(of: "хв", with: "").trimmingCharacters(in: .whitespaces)
                if val.contains("-") {
                    let comps = val.components(separatedBy: "-")
                    if comps.count == 2, let maxVal = Double(comps[1].trimmingCharacters(in: .whitespaces)) { initialETAMinutes = maxVal }
                } else if let minutes = Double(val) { initialETAMinutes = minutes }
            } else if cleanEta.hasSuffix("год") {
                let val = cleanEta.replacingOccurrences(of: "год", with: "").trimmingCharacters(in: .whitespaces)
                if val.contains("-") {
                    let comps = val.components(separatedBy: "-")
                    if comps.count == 2, let maxVal = Double(comps[1].trimmingCharacters(in: .whitespaces)) { initialETAMinutes = maxVal * 60.0 }
                } else if let hours = Double(val) { initialETAMinutes = hours * 60.0 }
            }

            if initialETAMinutes > 0 {
                remainingDistance = max(0, originalDistance - (originalDistance / initialETAMinutes) * elapsed)
            } else {
                remainingDistance = originalDistance
            }
        } else {
            let speed: Double = (type?.lowercased() == "ballistics" || type?.lowercased() == "kinzhal") ? 60.0 : 2.5
            remainingDistance = max(0, originalDistance - speed * Double(elapsed))
        }

        if remainingDistance <= 0 {
            let pattern = "(Відстань\\s+(до\\s+целі:|до\\s+цілі:)?\\s*~?\\d+\\s*км|Відстань:\\s*~?\\d+\\s*км)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let nsString = originalLine as NSString
                let replacement = (is_predictive == true) ? "На межі області (очікується офіційна тривога)" : "Ціль в області"
                let updated = regex.stringByReplacingMatches(in: originalLine, options: [], range: NSRange(location: 0, length: nsString.length), withTemplate: replacement)
                return updated
            }
            return originalLine.replacingOccurrences(of: String(format: "%.0f", originalDistance), with: "0")
        }

        return originalLine.replacingOccurrences(of: String(format: "%.0f", originalDistance),
                                                 with: String(format: "%.0f", remainingDistance))
    }
}
