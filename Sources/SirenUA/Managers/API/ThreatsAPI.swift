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

    var id: String { threat_id }

    var originCoordinate: CLLocationCoordinate2D? {
        if let lat = origin_latitude, let lon = origin_longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        if let transit = transit_from, let coord = RegionRegistry.regionalCoordinates[transit] {
            return coord
        }
        return nil
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
                          .trimmingCharacters(in: .whitespacesAndNewlines)

        // Case 1: Compound format, e.g. "1 год 16 хв" or "1 год 45 хв"
        if cleanEta.contains("год") && cleanEta.contains("хв") {
            let parts = cleanEta.components(separatedBy: "год")
            if parts.count == 2,
               let hr = Int(parts[0].trimmingCharacters(in: .whitespaces)),
               let mn = Int(parts[1].replacingOccurrences(of: "хв", with: "").trimmingCharacters(in: .whitespaces)) {
                let totalMins = hr * 60 + mn
                let remaining = totalMins - elapsed
                if remaining <= 0 { return "в області" }
                else if remaining < 60 { return "~\(remaining) хв" }
                else {
                    let rHr = remaining / 60; let rMn = remaining % 60
                    return rMn == 0 ? "~\(rHr) год" : "~\(rHr) год \(rMn) хв"
                }
            }
        }

        if cleanEta.hasSuffix("хв") {
            let valPart = cleanEta.replacingOccurrences(of: "хв", with: "").trimmingCharacters(in: .whitespaces)
            if valPart.contains("-") {
                let comps = valPart.components(separatedBy: "-")
                if comps.count == 2,
                   let minVal = Int(comps[0].trimmingCharacters(in: .whitespaces)),
                   let maxVal = Int(comps[1].trimmingCharacters(in: .whitespaces)) {
                    let newMin = max(0, minVal - elapsed)
                    let newMax = max(0, maxVal - elapsed)
                    if newMax == 0 { return "в області" }
                    else if newMin == 0 { return "~до \(newMax) хв" }
                    else { return "~\(newMin)-\(newMax) хв" }
                }
            } else if let minutes = Int(valPart) {
                let remaining = minutes - elapsed
                if remaining <= 0 { return "в області" }
                else if remaining < 60 { return "~\(remaining) хв" }
                else { let hr = remaining / 60; let mn = remaining % 60; return mn == 0 ? "~\(hr) год" : "~\(hr) год \(mn) хв" }
            }
        } else if cleanEta.hasSuffix("год") {
            let valPart = cleanEta.replacingOccurrences(of: "год", with: "").trimmingCharacters(in: .whitespaces)
            if valPart.contains("-") {
                let comps = valPart.components(separatedBy: "-")
                if comps.count == 2,
                   let minVal = Double(comps[0].trimmingCharacters(in: .whitespaces)),
                   let maxVal = Double(comps[1].trimmingCharacters(in: .whitespaces)) {
                    let minMin = Int(minVal * 60); let maxMin = Int(maxVal * 60)
                    let newMin = max(0, minMin - elapsed); let newMax = max(0, maxMin - elapsed)
                    if newMax == 0 { return "в області" }
                    let newMinHr = Double(newMin)/60.0; let newMaxHr = Double(newMax)/60.0
                    return newMin == 0 ? String(format: "~до %.1f год", newMaxHr) : String(format: "~%.1f-%.1f год", newMinHr, newMaxHr)
                }
            } else if let hours = Double(valPart) {
                let remainingMin = Int(hours * 60) - elapsed
                if remainingMin <= 0 { return "в області" }
                else if remainingMin < 60 { return "~до \(remainingMin) хв" }
                else { let hr = remainingMin / 60; let mn = remainingMin % 60; return mn == 0 ? "~\(hr) год" : "~\(hr) год \(mn) хв" }
            }
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
