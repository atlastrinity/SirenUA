import SwiftUI
import Foundation

#if canImport(UIKit)
import UIKit
#endif

extension AdminViewModel {
    func performDiagnostics() async {
        let startTime = Date()
        
        // 1. Alerts server ping
        do {
            var req = URLRequest(url: URL(string: "https://ubilling.net.ua/aerialalerts/")!)
            req.timeoutInterval = 3.0
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                alertsStatus = "ONLINE"
            } else {
                alertsStatus = "ERROR"
            }
        } catch { alertsStatus = "OFFLINE" }
        
        // 2. Analytics threat server ping
        guard let threatsUrl = URL(string: "\(serverURL)/api/threats") else { return }
        do {
            let req = makeAdminRequest(url: threatsUrl)
            let (_, res) = try await URLSession.shared.data(for: req)
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            if let http = res as? HTTPURLResponse {
                if http.statusCode == 200 {
                    threatsStatus = "ONLINE (\(latency) ms)"
                } else {
                    threatsStatus = "ERROR (\(http.statusCode))"
                }
            } else {
                threatsStatus = "ERROR"
            }
        } catch { 
            threatsStatus = "OFFLINE"
            serverLatencyMs = nil
        }
        
        // 3. Gemini status ping
        guard let geminiUrl = URL(string: "\(serverURL)/api/gemini/status") else { return }
        do {
            let (data, _) = try await fetchAdminData(from: geminiUrl)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String {
                if status == "ok" {
                    geminiStatus = "АКТИВНИЙ (OK)"
                } else if status == "mock" {
                    geminiStatus = "MOCK РЕЖИМ"
                } else {
                    geminiStatus = status.uppercased()
                }
            } else {
                geminiStatus = "НЕВІДОМО"
            }
        } catch { geminiStatus = "OFFLINE" }
    }

    func injectCustomThreat() async {
        guard let url = URL(string: "\(serverURL)/api/threats/mock") else { return }
        do {
            var body: [String: Any] = [
                "region": simRegion,
                "level": simLevel,
                "threat_type": simThreatType,
                "detail": simDetail,
                "confidence": Int(simConfidence)
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
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let detail = errorJson["detail"] as? String {
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
                   let updated = json["rules_updated"] as? Int {
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

