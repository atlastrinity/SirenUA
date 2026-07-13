import SwiftUI
import Foundation
import OSLog

private let adminLogger = Logger(subsystem: "com.sirenua", category: "AdminViewModel")


#if canImport(UIKit)
import UIKit
#endif

@MainActor
class AdminViewModel: ObservableObject {
    // Server status pings
    @Published var alertsStatus: String = "Перевірка..."
    @Published var threatsStatus: String = "Перевірка..."
    @Published var geminiStatus: String = "Перевірка..."
    
    // Filters
    @Published var daysFilter = 7
    @Published var rulesDaysFilter = 30
    
    // Chronology Filters
    @Published var chrRegionFilter = ""
    @Published var chrThreatTypeFilter = ""
    @Published var chrMatchFilter = ""
    
    // AI Rules Filters
    @Published var rulesTypeFilter = ""
    @Published var rulesThreatTypeFilter = ""
    @Published var rulesActionFilter = ""
    
    // Correlation Filters
    @Published var corDaysFilter = 7
    @Published var corRegionFilter = ""
    @Published var corThreatTypeFilter = ""
    @Published var corMatchFilter = ""
    @Published var corUseDateRange = false
    @Published var corDateFrom = Date().addingTimeInterval(-7*86400)
    @Published var corDateTo = Date()
    
    // Errors Filters
    @Published var errDaysFilter = 7
    @Published var errSourceFilter = ""
    @Published var errTypeFilter = ""
    @Published var expandedErrorId: Int? = nil
    
    // Manual Threat Simulation Form
    @Published var simRegion = "Київська область"
    @Published var simLevel = "high"
    @Published var simThreatType = "shahed"
    @Published var simDetail = "Група ударних БПЛА рухається курсом на Васильків"
    @Published var showSimSuccessMessage = false
    @Published var simSuccessText = ""
    
    // Data Loading states
    @Published var isLoading = false
    @Published var showRebuildSuccess = false
    
    // Tab Data Stores
    @Published var dashboardStats: AdminDashboardStatsResponse? = nil
    @Published var correlationV2Data: AdminChronologyV2Response? = nil
    @Published var chronologyData: AdminChronologyResponse? = nil
    @Published var activeRules: [GeminiRule] = []
    @Published var ruleAuditHistory: [GeminiRuleAuditEntry] = []
    @Published var errorsList: [AdminErrorEntry] = []
    @Published var errorStats: AdminErrorStatsResponse? = nil
    
    @Published var regionsList: [String] = []
    
    let serverURL = "https://sirenua-threatserver.onrender.com"
    
    // MARK: - Computeds
    
    var groupedCorrelationEvents: [(String, [AdminChronologyV2Entry])] {
        guard let events = correlationV2Data?.events else { return [] }
        let grouped = Dictionary(grouping: events) { ev in
            if let ts = ev.ai_timestamp, ts.count >= 10 {
                return String(ts.prefix(10))
            }
            return "Невідома дата"
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var groupedChronologyEvents: [(String, [AdminChronologyEntry])] {
        guard let events = chronologyData?.events else { return [] }
        let grouped = Dictionary(grouping: events) { ev in
            if let ts = ev.threat_timestamp, ts.count >= 10 {
                return String(ts.prefix(10))
            }
            return "Невідома дата"
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    // MARK: - API Calls & Actions
    
    func refreshCurrentTab(selectedTab: Int) async {
        switch selectedTab {
        case 0:
            await fetchDashboardStats()
        case 1:
            await fetchCorrelationV2()
        case 2:
            await fetchChronology()
        case 3:
            await fetchRules()
        case 4:
            await fetchErrors()
        default:
            await performDiagnostics()
        }
    }
    
    func refreshAllData() async {
        isLoading = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchDashboardStats() }
            group.addTask { await self.fetchCorrelationV2() }
            group.addTask { await self.fetchChronology() }
            group.addTask { await self.fetchRules() }
            group.addTask { await self.fetchErrors() }
            group.addTask { await self.performDiagnostics() }
        }
        isLoading = false
    }
    
    func fetchDashboardStats() async {
        let url = URL(string: "\(serverURL)/api/admin/dashboard/stats")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let decoded = try? JSONDecoder().decode(AdminDashboardStatsResponse.self, from: data) {
                self.dashboardStats = decoded
            }
        } catch {}
    }
    
    func fetchCorrelationV2() async {
        var params = ""
        
        if corUseDateRange {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let fromStr = formatter.string(from: corDateFrom)
            let toStr = formatter.string(from: corDateTo)
            params = "date_from=\(fromStr)&date_to=\(toStr)"
        } else {
            params = "days=\(corDaysFilter)"
        }
        
        if !corRegionFilter.isEmpty {
            if let escaped = corRegionFilter.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                params += "&region=\(escaped)"
            }
        }
        if !corThreatTypeFilter.isEmpty {
            params += "&threat_type=\(corThreatTypeFilter)"
        }
        if !corMatchFilter.isEmpty {
            params += "&match_result=\(corMatchFilter)"
        }
        
        let url = URL(string: "\(serverURL)/api/admin/chronology/v2?\(params)")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            do {
                let decoded = try JSONDecoder().decode(AdminChronologyV2Response.self, from: data)
                self.correlationV2Data = decoded
            } catch {
                adminLogger.error("Failed to decode AdminChronologyV2Response: \(error)")
            }
        } catch {
            adminLogger.error("Network error in fetchCorrelationV2: \(error)")
        }
    }
    
    func fetchChronology() async {
        var params = "days=\(daysFilter)"
        if !chrRegionFilter.isEmpty {
            if let escaped = chrRegionFilter.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                params += "&region=\(escaped)"
            }
        }
        if !chrThreatTypeFilter.isEmpty {
            params += "&threat_type=\(chrThreatTypeFilter)"
        }
        if !chrMatchFilter.isEmpty {
            params += "&prediction_accuracy=\(chrMatchFilter)"
        }
        
        let url = URL(string: "\(serverURL)/api/admin/chronology?\(params)")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            do {
                let decoded = try JSONDecoder().decode(AdminChronologyResponse.self, from: data)
                self.chronologyData = decoded
            } catch {
                adminLogger.error("Failed to decode AdminChronologyResponse: \(error)")
            }
        } catch {
            adminLogger.error("Network error in fetchChronology: \(error)")
        }
    }
    
    func fetchRules() async {
        var rulesParams = "active_only=true&limit=100"
        if !rulesTypeFilter.isEmpty {
            rulesParams += "&rule_type=\(rulesTypeFilter)"
        }
        if !rulesThreatTypeFilter.isEmpty {
            rulesParams += "&threat_type=\(rulesThreatTypeFilter)"
        }
        
        var auditParams = "days=\(rulesDaysFilter)"
        if !rulesTypeFilter.isEmpty {
            auditParams += "&rule_type=\(rulesTypeFilter)"
        }
        if !rulesThreatTypeFilter.isEmpty {
            auditParams += "&threat_type=\(rulesThreatTypeFilter)"
        }
        if !rulesActionFilter.isEmpty {
            auditParams += "&action=\(rulesActionFilter)"
        }
        
        do {
            let rulesUrl = URL(string: "\(serverURL)/api/analytics/rules?\(rulesParams)")!
            let historyUrl = URL(string: "\(serverURL)/api/admin/rules/history?\(auditParams)")!
            
            let (rulesData, _) = try await URLSession.shared.data(from: rulesUrl)
            let (historyData, _) = try await URLSession.shared.data(from: historyUrl)
            
            if let decodedRules = try? JSONDecoder().decode(GeminiRulesResponse.self, from: rulesData) {
                self.activeRules = decodedRules.rules
            }
            
            if let decodedHistory = try? JSONDecoder().decode(GeminiRulesHistoryResponse.self, from: historyData) {
                self.ruleAuditHistory = decodedHistory.entries
            }
        } catch {}
    }
    
    func fetchErrors() async {
        let params = "days=\(errDaysFilter)" + (errSourceFilter.isEmpty ? "" : "&source=\(errSourceFilter)") + (errTypeFilter.isEmpty ? "" : "&error_type=\(errTypeFilter)")
        
        do {
            let statsUrl = URL(string: "\(serverURL)/api/admin/errors/stats?days=\(errDaysFilter)")!
            let errorsUrl = URL(string: "\(serverURL)/api/admin/errors?\(params)")!
            
            let (statsData, _) = try await URLSession.shared.data(from: statsUrl)
            let (errorsData, _) = try await URLSession.shared.data(from: errorsUrl)
            
            if let decodedStats = try? JSONDecoder().decode(AdminErrorStatsResponse.self, from: statsData) {
                self.errorStats = decodedStats
            }
            
            if let decodedErrors = try? JSONDecoder().decode(AdminErrorsResponse.self, from: errorsData) {
                self.errorsList = decodedErrors.errors
            }
        } catch {}
    }
    
    func loadRegions() async {
        let url = URL(string: "\(serverURL)/api/threats")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let threats = json["threats"] as? [String: Any] {
                self.regionsList = threats.keys.sorted()
            }
        } catch {}
    }
    
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
        do {
            var req = URLRequest(url: URL(string: "\(serverURL)/api/threats")!)
            req.timeoutInterval = 3.0
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                threatsStatus = "ONLINE"
            } else {
                threatsStatus = "ERROR"
            }
        } catch { threatsStatus = "OFFLINE" }
        
        // 3. Gemini status ping
        do {
            var req = URLRequest(url: URL(string: "\(serverURL)/api/gemini/status")!)
            req.timeoutInterval = 3.0
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String {
                geminiStatus = status.uppercased()
            } else {
                geminiStatus = "UNKNOWN"
            }
        } catch { geminiStatus = "OFFLINE" }
    }
    
    func rebuildRules() async {
        do {
            var req = URLRequest(url: URL(string: "\(serverURL)/api/analytics/rules/rebuild")!)
            req.httpMethod = "POST"
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                showRebuildSuccess = true
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                showRebuildSuccess = false
                await fetchRules()
            }
        } catch {}
    }
    
    func injectCustomThreat() async {
        do {
            var req = URLRequest(url: URL(string: "\(serverURL)/api/threats/mock")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "region": simRegion,
                "level": simLevel,
                "threat_type": simThreatType,
                "detail": simDetail
            ]
            
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
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
    
    // MARK: - Helpers
    
    func formatShortTime(_ ts: String) -> String {
        guard ts.count >= 19 else { return ts }
        let cleanTs = ts.replacingOccurrences(of: "T", with: " ")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        if let date = formatter.date(from: String(cleanTs.prefix(19))) {
            let localFormatter = DateFormatter()
            localFormatter.timeStyle = .short
            localFormatter.dateStyle = .short
            localFormatter.timeZone = TimeZone.current
            return localFormatter.string(from: date)
        }
        return String(ts.suffix(8))
    }
    
    func formatShortDate(_ dateStr: String) -> String {
        guard dateStr.count >= 10 else { return dateStr }
        return String(dateStr.suffix(5))
    }
    
    func formatDuration(_ sec: Int) -> String {
        let positiveSec = abs(sec)
        if positiveSec < 60 { return "\(positiveSec)с" }
        if positiveSec < 3600 { return "\(positiveSec / 60)хв" }
        return "\(positiveSec / 3600)год"
    }
    
    func formatErrorType(_ type: String) -> String {
        switch type {
        case "429_rate_limit": return "429 Ліміт запитів"
        case "404_not_found": return "404 Не знайдено"
        case "500_server": return "500 Помилка сервера"
        case "timeout": return "Таймаут з'єднання"
        case "network_error": return "Мережевий збій"
        case "auth": return "Помилка автентифікації"
        case "systemic": return "Системна помилка"
        case "firebase_error": return "Firebase/FCM збій"
        case "telegram_error": return "Telegram API збій"
        case "gemini_api_error": return "Gemini API збій"
        case "json_parse_error": return "Помилка парсингу JSON"
        case "database_error": return "Помилка бази даних"
        case "validation_error": return "Помилка валідації"
        case "general": return "Загальна помилка"
        default: return type
        }
    }
    
    func triggerHaptic(_ style: String = "medium") {
        #if canImport(UIKit)
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case "light": feedbackStyle = .light
        case "heavy": feedbackStyle = .heavy
        default: feedbackStyle = .medium
        }
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
        #endif
    }
}
