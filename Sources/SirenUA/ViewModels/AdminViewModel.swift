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
    @Published var ukraineAlarmStatus: String = "Перевірка..."
    @Published var ubillingStatus: String = "Перевірка..."
    @Published var alertsInUaStatus: String = "Перевірка..."
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
    
    @AppStorage("customServerURL") var customServerURLSetting: String = ""

    // Manual Threat Simulation Form
    @Published var simRegion = "Київська область"
    @Published var simLevel = "high"
    @Published var simThreatType = "shahed"
    @Published var simDetail = "Група ударних БПЛА рухається курсом на Васильків"
    @Published var simConfidence: Double = 85.0
    @Published var simSpeedKmh: String = "185"
    @Published var simHeadingDegrees: String = "280"
    @Published var simAttackVector: String = "south_to_north"
    @Published var isAdvancedTelemetryExpanded: Bool = false
    @Published var isTriggeringScenario: String? = nil
    @Published var isClearingThreats: Bool = false
    @Published var isTriggeringLearner: Bool = false
    @Published var isRestartingServer: Bool = false
    @Published var serverLatencyMs: Int? = nil
    @Published var showSimSuccessMessage = false
    @Published var simSuccessText = ""
    
    // Data Loading states
    @Published var isLoading = false
    @Published var showRebuildSuccess = false
    @Published var lastFetchError: String? = nil
    
    // Tab Data Stores
    @Published var dashboardStats: AdminDashboardStatsResponse? = nil
    @Published var correlationV2Data: AdminChronologyV2Response? = nil
    @Published var chronologyData: AdminChronologyResponse? = nil
    @Published var selectedRuleRegion: String = "Сумська область"
    @Published var regionalRuleMetrics: [String: AdminRegionRuleMetrics] = [:]

    @Published var activeRules: [GeminiRule] = []
    @Published var ruleAuditHistory: [GeminiRuleAuditEntry] = []
    @Published var errorsList: [AdminErrorEntry] = []
    @Published var errorStats: AdminErrorStatsResponse? = nil
    
    // Post-Mortem State
    @Published var isTriggeringPostMortem: Bool = false
    @Published var showPostMortemSuccess: Bool = false
    @Published var postMortemResultText: String = ""
    
    // Palantir Data Store
    @Published var palantirOverview: PalantirOverviewResponse? = nil
    @Published var palantirReportsList: [PalantirReportEntry] = []
    @Published var palantirDaysFilter: Int = 30
    @Published var isSynthesizingPalantir: Bool = false
    
    @Published var regionsList: [String] = []
    
    var serverURL: String {
        NetworkManager.serverURL
    }

    func setServerURL(_ newURL: String) {
        let trimmed = newURL.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: "customServerURL")
        objectWillChange.send()
        Task {
            await refreshAllData()
        }
    }
    
    private nonisolated static let utcDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private nonisolated static let kyivDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Kyiv") ?? TimeZone.current
        return formatter
    }()

    private static let shortTimeLocalFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    // MARK: - Computeds & Helpers
    
    func localDateString(from utcTimestamp: String?) -> String {
        guard let ts = utcTimestamp, ts.count >= 10 else { return "Невідома дата" }
        let cleanTs = ts.replacingOccurrences(of: "T", with: " ")
        if let date = Self.utcDateFormatter.date(from: String(cleanTs.prefix(19))) {
            return Self.kyivDateFormatter.string(from: date)
        }
        return String(ts.prefix(10))
    }

    @Published var groupedCorrelationEvents: [(String, [AdminChronologyV2Entry])] = []
    @Published var groupedChronologyEvents: [(String, [AdminChronologyEntry])] = []
    
    var rulesGroupedByRegion: [(String, [GeminiRule])] {
        let grouped = Dictionary(grouping: activeRules) { rule in
            if let target = rule.target_region, !target.isEmpty {
                return target
            }
            if let source = rule.source_region, !source.isEmpty {
                return source
            }
            return "Загальні правила"
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    // MARK: - API Calls & Actions
    
    func makeAdminRequest(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("ios-sirenua-admin/4.2", forHTTPHeaderField: "User-Agent")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        req.timeoutInterval = 8.0
        return req
    }
    
    func fetchAdminData(from url: URL) async throws -> (Data, URLResponse) {
        let req = makeAdminRequest(url: url)
        return try await URLSession.shared.data(for: req)
    }

    private func decodeInBackground<T: Decodable>(_ type: T.Type, from data: Data) async throws -> T {
        try await Task.detached(priority: .userInitiated) {
            try JSONDecoder().decode(T.self, from: data)
        }.value
    }
    
    private var activeFetchTabs = Set<Int>()

    func refreshCurrentTab(selectedTab: Int) async {
        guard !activeFetchTabs.contains(selectedTab) else { return }
        activeFetchTabs.insert(selectedTab)
        defer { activeFetchTabs.remove(selectedTab) }

        switch selectedTab {
        case 0:
            await fetchDashboardStats()
        case 1:
            await fetchPalantirOverview()
        case 2:
            await fetchCorrelationV2()
        case 3:
            await fetchChronology()
        case 4:
            await fetchRules()
        case 5:
            await fetchErrors()
        default:
            await performDiagnostics()
        }
    }
    
    func refreshAllData(selectedTab: Int = 0) async {
        if dashboardStats == nil && correlationV2Data == nil && palantirOverview == nil {
            isLoading = true
        }
        lastFetchError = nil
        
        // Fast path: load only current active tab for instantaneous presentation
        await refreshCurrentTab(selectedTab: selectedTab)
        isLoading = false
    }
    
    func fetchDashboardStats() async {
        guard let url = URL(string: "\(serverURL)/api/admin/dashboard/stats") else { return }
        do {
            let (data, response) = try await fetchAdminData(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                self.lastFetchError = "Сервер повернув HTTP \(http.statusCode)"
                adminLogger.error("HTTP \(http.statusCode) from fetchDashboardStats")
                return
            }
            do {
                let decoded = try await decodeInBackground(AdminDashboardStatsResponse.self, from: data)
                self.dashboardStats = decoded
            } catch {
                adminLogger.error("Failed to decode AdminDashboardStatsResponse: \(error)")
                self.lastFetchError = "Помилка декодування статистики: \(error.localizedDescription)"
            }
        } catch {
            adminLogger.error("Network error in fetchDashboardStats: \(error)")
            self.lastFetchError = "Помилка мережі: \(error.localizedDescription)"
        }
    }
    
    func fetchCorrelationV2() async {
        var params = ""
        
        if corUseDateRange {
            let fromStr = Self.kyivDateFormatter.string(from: corDateFrom)
            let toStr = Self.kyivDateFormatter.string(from: corDateTo)
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
        
        guard let url = URL(string: "\(serverURL)/api/admin/chronology/v2?\(params)") else { return }
        do {
            let (data, _) = try await fetchAdminData(from: url)
            do {
                let decoded = try await decodeInBackground(AdminChronologyV2Response.self, from: data)
                self.correlationV2Data = decoded
                
                // Precompute grouped events off main thread
                let events = decoded.events ?? []
                let grouped = await Task.detached(priority: .userInitiated) { () -> [(String, [AdminChronologyV2Entry])] in
                    let dict = Dictionary(grouping: events) { ev in
                        guard let ts = ev.ai_timestamp, ts.count >= 10 else { return "Невідома дата" }
                        let cleanTs = ts.replacingOccurrences(of: "T", with: " ")
                        if let date = Self.utcDateFormatter.date(from: String(cleanTs.prefix(19))) {
                            return Self.kyivDateFormatter.string(from: date)
                        }
                        return String(ts.prefix(10))
                    }
                    return dict.sorted { $0.key > $1.key }
                }.value
                self.groupedCorrelationEvents = grouped
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
        
        guard let url = URL(string: "\(serverURL)/api/admin/chronology?\(params)") else { return }
        do {
            let (data, _) = try await fetchAdminData(from: url)
            do {
                let decoded = try await decodeInBackground(AdminChronologyResponse.self, from: data)
                self.chronologyData = decoded
                
                // Precompute grouped chronology off main thread
                let events = decoded.events
                let grouped = await Task.detached(priority: .userInitiated) { () -> [(String, [AdminChronologyEntry])] in
                    let dict = Dictionary(grouping: events) { ev in
                        guard let ts = ev.threat_timestamp, ts.count >= 10 else { return "Невідома дата" }
                        let cleanTs = ts.replacingOccurrences(of: "T", with: " ")
                        if let date = Self.utcDateFormatter.date(from: String(cleanTs.prefix(19))) {
                            return Self.kyivDateFormatter.string(from: date)
                        }
                        return String(ts.prefix(10))
                    }
                    return dict.sorted { $0.key > $1.key }
                }.value
                self.groupedChronologyEvents = grouped
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
            guard let rulesUrl = URL(string: "\(serverURL)/api/analytics/rules?\(rulesParams)"),
                  let historyUrl = URL(string: "\(serverURL)/api/admin/rules/history?\(auditParams)"),
                  let metricsUrl = URL(string: "\(serverURL)/api/admin/rules/metrics_by_region") else { return }
            
            async let rulesFetch = fetchAdminData(from: rulesUrl)
            async let historyFetch = fetchAdminData(from: historyUrl)
            async let metricsFetch = fetchAdminData(from: metricsUrl)
            
            let (rulesData, _) = try await rulesFetch
            let (historyData, _) = try await historyFetch
            let (metricsData, _) = try await metricsFetch
            
            if let decoded = try? await decodeInBackground(GeminiRulesResponse.self, from: rulesData) {
                self.activeRules = decoded.rules
            }
            
            if let decoded = try? await decodeInBackground(GeminiRulesHistoryResponse.self, from: historyData) {
                self.ruleAuditHistory = decoded.entries
            }

            if let decoded = try? await decodeInBackground(AdminRulesMetricsResponse.self, from: metricsData) {
                self.regionalRuleMetrics = decoded.region_metrics
            }
        } catch {
            adminLogger.error("❌ fetchRules network/request error: \(error)")
        }
    }
    
    func fetchErrors() async {
        let params = "days=\(errDaysFilter)" + (errSourceFilter.isEmpty ? "" : "&source=\(errSourceFilter)") + (errTypeFilter.isEmpty ? "" : "&error_type=\(errTypeFilter)")
        
        do {
            guard let statsUrl = URL(string: "\(serverURL)/api/admin/errors/stats?days=\(errDaysFilter)"),
                  let errorsUrl = URL(string: "\(serverURL)/api/admin/errors?\(params)") else { return }
            
            async let statsFetch = fetchAdminData(from: statsUrl)
            async let errorsFetch = fetchAdminData(from: errorsUrl)
            
            let (statsData, _) = try await statsFetch
            let (errorsData, _) = try await errorsFetch
            
            if let decodedStats = try? await decodeInBackground(AdminErrorStatsResponse.self, from: statsData) {
                self.errorStats = decodedStats
            }
            
            if let decodedErrors = try? await decodeInBackground(AdminErrorsResponse.self, from: errorsData) {
                self.errorsList = decodedErrors.errors
            }
        } catch {}
    }
    
    func clearErrors(source: String? = nil, errorType: String? = nil) async {
        var queryItems: [String] = []
        if let s = source, !s.isEmpty { queryItems.append("source=\(s)") }
        if let t = errorType, !t.isEmpty { queryItems.append("error_type=\(t)") }
        let queryString = queryItems.isEmpty ? "" : "?" + queryItems.joined(separator: "&")
        
        guard let url = URL(string: "\(serverURL)/api/admin/errors\(queryString)") else { return }
        let req = makeAdminRequest(url: url, method: "DELETE")
        do {
            _ = try await URLSession.shared.data(for: req)
            await fetchErrors()
            await fetchDashboardStats()
        } catch {
            adminLogger.error("Failed to clear errors: \(error)")
        }
    }
    
    func fetchPalantirOverview() async {
        guard let url = URL(string: "\(serverURL)/api/admin/palantir/overview?days=\(palantirDaysFilter)"),
              let reportsUrl = URL(string: "\(serverURL)/api/admin/palantir/reports?limit=20") else { return }
        do {
            async let overviewFetch = fetchAdminData(from: url)
            async let reportsFetch = fetchAdminData(from: reportsUrl)
            
            let (overviewData, _) = try await overviewFetch
            let (reportsData, _) = try await reportsFetch
            
            if let decoded = try? await decodeInBackground(PalantirOverviewResponse.self, from: overviewData) {
                self.palantirOverview = decoded
            }
            if let decoded = try? await decodeInBackground(PalantirReportsResponse.self, from: reportsData) {
                self.palantirReportsList = decoded.reports
            }
        } catch {
            guard !Task.isCancelled, (error as? URLError)?.code != .cancelled, (error as NSError).code != -999 else { return }
            adminLogger.error("Failed in fetchPalantirOverview: \(error)")
        }
    }
    
    func triggerPalantirSynthesis() async {
        guard let url = URL(string: "\(serverURL)/api/admin/palantir/synthesize") else { return }
        isSynthesizingPalantir = true
        do {
            let req = makeAdminRequest(url: url, method: "POST")
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                triggerHaptic("heavy")
                await fetchPalantirOverview()
            }
        } catch {
            adminLogger.error("Palantir synthesis error: \(error)")
        }
        isSynthesizingPalantir = false
    }
    
    func loadRegions() async {
        guard let url = URL(string: "\(serverURL)/api/threats") else { return }
        do {
            let (data, _) = try await fetchAdminData(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let threats = json["threats"] as? [String: Any] {
                self.regionsList = threats.keys.sorted()
            }
        } catch {}
    }
    
    func rebuildRules() async {
        guard let url = URL(string: "\(serverURL)/api/analytics/rules/rebuild") else { return }
        do {
            let req = makeAdminRequest(url: url, method: "POST")
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                showRebuildSuccess = true
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                showRebuildSuccess = false
                await fetchRules()
            }
        } catch {}
    }
    
    func triggerPostMortem(hours: Int = 4) async {
        guard let url = URL(string: "\(serverURL)/api/admin/rules/post_mortem?hours=\(hours)") else { return }
        isTriggeringPostMortem = true
        do {
            let req = makeAdminRequest(url: url, method: "POST")
            let (data, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                if let decoded = try? JSONDecoder().decode(PostMortemResponse.self, from: data) {
                    postMortemResultText = "ШІ сформував \(decoded.rules_created ?? 0) нових правил"
                } else {
                    postMortemResultText = "Рефлексію Post-Mortem виконано успішно"
                }
                showPostMortemSuccess = true
                triggerHaptic("heavy")
                await fetchRules()
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                showPostMortemSuccess = false
            }
        } catch {
            adminLogger.error("Post-Mortem trigger error: \(error)")
        }
        isTriggeringPostMortem = false
    }
    
    func restartServer() async {
        guard let url = URL(string: "\(serverURL)/api/admin/restart") else { return }
        isRestartingServer = true
        triggerHaptic("medium")
        do {
            let req = makeAdminRequest(url: url, method: "POST")
            _ = try await URLSession.shared.data(for: req)
            
            // Wait 2.5 seconds for process restart
            try await Task.sleep(nanoseconds: 2_500_000_000)
            
            // Poll health check to confirm server is back online
            for _ in 0..<10 {
                if await checkServerAlive() {
                    break
                }
                try await Task.sleep(nanoseconds: 800_000_000)
            }
            
            simSuccessText = "Сервер успішно перезавантажено!"
            showSimSuccessMessage = true
            triggerHaptic("heavy")
            await refreshAllData()
            await performDiagnostics()
            
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showSimSuccessMessage = false
        } catch {
            adminLogger.error("Restart server error: \(error)")
        }
        isRestartingServer = false
    }
    
    private func checkServerAlive() async -> Bool {
        guard let url = URL(string: "\(serverURL)/api/gemini/status") else { return false }
        do {
            let (data, res) = try await fetchAdminData(from: url)
            return (res as? HTTPURLResponse)?.statusCode == 200 && !data.isEmpty
        } catch {
            return false
        }
    }
    
    // MARK: - Helpers
    
    func formatShortTime(_ ts: String) -> String {
        guard ts.count >= 19 else { return ts }
        let cleanTs = ts.replacingOccurrences(of: "T", with: " ")
        if let date = Self.utcDateFormatter.date(from: String(cleanTs.prefix(19))) {
            return Self.shortTimeLocalFormatter.string(from: date)
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
        let hours = positiveSec / 3600
        let minutes = (positiveSec % 3600) / 60
        if minutes > 0 {
            return "\(hours)год \(minutes)хв"
        } else {
            return "\(hours)год"
        }
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
