import Foundation
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

@MainActor
extension AdminViewModel {
    func performDiagnostics() async {
        let startTime = Date()
        let sUrl = self.serverURL

        async let pingUA: String = {
            do {
                var req = URLRequest(
                    url: URL(string: "https://api.ukrainealarm.com/api/v3/alerts")!)
                req.timeoutInterval = 2.5
                req.setValue("SirenUA-Admin/1.0", forHTTPHeaderField: "User-Agent")
                let start = Date()

                let (_, res) = try await URLSession.shared.data(for: req)
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                if let http = res as? HTTPURLResponse {
                    if http.statusCode == 200 {
                        return "ONLINE (\(ms) ms)"
                    } else if http.statusCode == 401 || http.statusCode == 403 {
                        return "ОЧІКУЄ КЛЮЧ (\(ms) ms)"
                    } else {
                        return "HTTP \(http.statusCode)"
                    }
                }
                return "ERROR"
            } catch { return "OFFLINE" }
        }()

        async let pingUB: String = {
            do {
                var req = URLRequest(url: URL(string: "https://ubilling.net.ua/aerialalerts/")!)
                req.timeoutInterval = 2.5
                let start = Date()
                let (_, res) = try await URLSession.shared.data(for: req)
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                    return "ONLINE (\(ms) ms)"
                }
                return "ERROR"
            } catch { return "OFFLINE" }
        }()

        async let pingAlerts: String = {
            do {
                var req = URLRequest(
                    url: URL(string: "https://api.alerts.in.ua/v1/alerts/active.json")!)
                req.timeoutInterval = 2.5
                let start = Date()
                let (_, res) = try await URLSession.shared.data(for: req)
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                if let http = res as? HTTPURLResponse {
                    if http.statusCode == 200 {
                        return "ONLINE (\(ms) ms)"
                    } else if http.statusCode == 401 || http.statusCode == 403 {
                        return "ОЧІКУЄ ТОКЕН (\(ms) ms)"
                    } else if http.statusCode == 429 {
                        return "ЛІМІТ ЗАПИТІВ"
                    } else {
                        return "HTTP \(http.statusCode)"
                    }
                }
                return "ERROR"
            } catch { return "OFFLINE" }
        }()

        async let pingThr: (String, Int?) = {
            guard let threatsUrl = URL(string: "\(sUrl)/api/threats") else {
                return ("OFFLINE", nil)
            }
            do {
                var req = URLRequest(url: threatsUrl)
                req.timeoutInterval = 5.0
                req.setValue("SirenUA-Admin/1.0", forHTTPHeaderField: "User-Agent")
                req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
                req.setValue("application/json", forHTTPHeaderField: "Accept")
                let (_, res) = try await URLSession.shared.data(for: req)
                let latency = Int(Date().timeIntervalSince(startTime) * 1000)
                if let http = res as? HTTPURLResponse {
                    if http.statusCode == 200 {
                        return ("ONLINE (\(latency) ms)", latency)
                    } else {
                        return ("ERROR (\(http.statusCode))", nil)
                    }
                }
                return ("ERROR", nil)
            } catch { return ("OFFLINE", nil) }
        }()

        async let pingGem: String = {
            guard let geminiUrl = URL(string: "\(sUrl)/api/gemini/status") else { return "OFFLINE" }
            do {
                var req = URLRequest(url: geminiUrl)
                req.timeoutInterval = 5.0
                req.setValue("SirenUA-Admin/1.0", forHTTPHeaderField: "User-Agent")
                req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
                req.setValue("application/json", forHTTPHeaderField: "Accept")
                let (data, _) = try await URLSession.shared.data(for: req)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let status = json["status"] as? String
                {
                    if status == "ok" {
                        let keys = json["keys_count"] as? Int ?? 1
                        return "АКТИВНИЙ (\(keys) key)"
                    } else if status == "mock" {
                        return "MOCK РЕЖИМ"
                    } else {
                        return status.uppercased()
                    }
                }
                return "НЕВІДОМО"
            } catch { return "OFFLINE" }
        }()

        let (ua, ub, al, (thr, lat), gem) = await (pingUA, pingUB, pingAlerts, pingThr, pingGem)
        self.ukraineAlarmStatus = ua
        self.ubillingStatus = ub
        self.alertsStatus = ub
        self.alertsInUaStatus = al
        self.threatsStatus = thr
        self.serverLatencyMs = lat
        self.geminiStatus = gem
    }

    func injectCustomThreat() async {
        guard let url = URL(string: "\(serverURL)/api/threats/mock") else { return }
        do {
            var body: [String: Any] = [
                "region": simRegion,
                "level": simLevel,
                "threat_type": simThreatType,
                "detail": simDetail,
                "confidence": Int(simConfidence),
            ]

            if isAdvancedTelemetryExpanded {
                var telemetry: [String: Any] = [:]
                if let speed = Int(simSpeedKmh), speed > 0 {
                    telemetry["speed_kmh"] = speed
                }
                if let heading = Int(simHeadingDegrees), heading >= 0 && heading <= 360 {
                    telemetry["heading_degrees"] = heading
                }
                if !simAttackVector.isEmpty {
                    telemetry["attack_vector"] = simAttackVector
                }
                if !telemetry.isEmpty {
                    body["telemetry"] = telemetry
                }
            }

            let jsonData = try JSONSerialization.data(withJSONObject: body)
            let req = makeAdminRequest(url: url, method: "POST", body: jsonData)

            let (data, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse {
                if http.statusCode == 200 {
                    triggerHaptic("heavy")
                    simSuccessText = "✅ Загрозу (\(simThreatType)) надіслано в \(simRegion)!"
                    showSimSuccessMessage = true
                    await fetchChronology()
                    await fetchDashboardStats()
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    showSimSuccessMessage = false
                } else {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data)
                        as? [String: Any],
                        let detail = errorJson["detail"] as? String
                    {
                        simSuccessText = "⚠️ Помилка: \(detail)"
                    } else {
                        simSuccessText = "⚠️ Помилка сервера (\(http.statusCode))"
                    }
                    showSimSuccessMessage = true
                }
            }
        } catch {
            simSuccessText = "⚠️ Помилка мережі: \(error.localizedDescription)"
            showSimSuccessMessage = true
        }
    }

    func seedHistory() async {
        guard let url = URL(string: "\(serverURL)/api/admin/seed_history") else { return }
        do {
            let req = makeAdminRequest(url: url, method: "POST")
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                triggerHaptic("heavy")
                simSuccessText = "✅ Успішно додано початкові демо-дані!"
                showSimSuccessMessage = true
                await refreshAllData()
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                showSimSuccessMessage = false
            }
        } catch {
            lastFetchError = "Помилка генерації демо-даних: \(error.localizedDescription)"
        }
    }

    func postTriggerScenario(_ scenario: String) async {
        isTriggeringScenario = scenario
        triggerHaptic("medium")
        guard let url = URL(string: "\(serverURL)/api/threats/scenario") else {
            isTriggeringScenario = nil
            return
        }
        do {
            let body = ["scenario": scenario]
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            let req = makeAdminRequest(url: url, method: "POST", body: jsonData)
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                triggerHaptic("heavy")
                simSuccessText = "🚀 Сценарій '\(scenario)' успішно активовано!"
                showSimSuccessMessage = true
                await fetchChronology()
                await fetchDashboardStats()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                showSimSuccessMessage = false
            }
        } catch {
            simSuccessText = "⚠️ Помилка активації сценарію: \(error.localizedDescription)"
            showSimSuccessMessage = true
        }
        isTriggeringScenario = nil
    }

    func postClearAll() async {
        isClearingThreats = true
        triggerHaptic("heavy")
        guard let url = URL(string: "\(serverURL)/api/threats/scenario") else {
            isClearingThreats = false
            return
        }
        do {
            let body = ["scenario": "clear"]
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            let req = makeAdminRequest(url: url, method: "POST", body: jsonData)
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                triggerHaptic("heavy")
                simSuccessText = "🧹 Всі загрози очищено, систему скинуто!"
                showSimSuccessMessage = true
                await fetchChronology()
                await fetchDashboardStats()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                showSimSuccessMessage = false
            }
        } catch {
            simSuccessText = "⚠️ Помилка очищення: \(error.localizedDescription)"
            showSimSuccessMessage = true
        }
        isClearingThreats = false
    }

    func triggerLearner() async {
        isTriggeringLearner = true
        triggerHaptic("medium")
        guard let url = URL(string: "\(serverURL)/api/analytics/predictions/learn") else {
            isTriggeringLearner = false
            return
        }
        do {
            let req = makeAdminRequest(url: url, method: "POST")
            let (data, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                triggerHaptic("heavy")
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let created = json["rules_created"] as? Int,
                    let updated = json["rules_updated"] as? Int
                {
                    simSuccessText = "🧠 Learner: створено \(created), оновлено \(updated) правил"
                } else {
                    simSuccessText = "🧠 Rules Learner виконано успішно"
                }
                showSimSuccessMessage = true
                await fetchRules()
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                showSimSuccessMessage = false
            }
        } catch {
            simSuccessText = "⚠️ Помилка Rules Learner: \(error.localizedDescription)"
            showSimSuccessMessage = true
        }
        isTriggeringLearner = false
    }
}
