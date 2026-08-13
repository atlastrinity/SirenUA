import SwiftUI
import Foundation

#if canImport(UIKit)
import UIKit
#endif

extension AdminViewModel {
    func performDiagnostics() async {
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
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                threatsStatus = "ONLINE"
            } else {
                threatsStatus = "ERROR"
            }
        } catch { threatsStatus = "OFFLINE" }
        
        // 3. Gemini status ping
        guard let geminiUrl = URL(string: "\(serverURL)/api/gemini/status") else { return }
        do {
            let (data, _) = try await fetchAdminData(from: geminiUrl)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String {
                geminiStatus = status.uppercased()
            } else {
                geminiStatus = "UNKNOWN"
            }
        } catch { geminiStatus = "OFFLINE" }
    }

    func injectCustomThreat() async {
        guard let url = URL(string: "\(serverURL)/api/threats/mock") else { return }
        do {
            let body: [String: Any] = [
                "region": simRegion,
                "level": simLevel,
                "threat_type": simThreatType,
                "detail": simDetail
            ]
            let jsonData = try? JSONSerialization.data(withJSONObject: body)
            let req = makeAdminRequest(url: url, method: "POST", body: jsonData)
            
            let (data, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse {
                if http.statusCode == 200 {
                    simSuccessText = "✅ Загрозу успішно надіслано в \(simRegion)!"
                    showSimSuccessMessage = true
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
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
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                simSuccessText = "Успішно додано початкові демо-дані!"
                showSimSuccessMessage = true
                await refreshAllData()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                showSimSuccessMessage = false
            }
        } catch {
            lastFetchError = "Помилка генерації демо-даних: \(error.localizedDescription)"
        }
    }

    func postTriggerScenario(_ scenario: String) async {
        do {
            var req = URLRequest(url: URL(string: "\(serverURL)/api/threats/scenario")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ["scenario": scenario]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                await fetchChronology()
            }
        } catch {}
    }

    func postClearAll() async {
        do {
            var req = URLRequest(url: URL(string: "\(serverURL)/api/threats/clear")!)
            req.httpMethod = "POST"
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                await fetchChronology()
            }
        } catch {}
    }
}
