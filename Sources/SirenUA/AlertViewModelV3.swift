import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import CoreLocation
import Combine
import OSLog

private let vmLogger = Logger(subsystem: "com.sirenua", category: "AlertViewModel")

@MainActor
final class AlertViewModelV3: ObservableObject {
    @Published var alerts: [AlertRegion] = []
    @Published var activeAlerts: Int = 0
    @Published var maxLevel: Int = 0
    @Published var showAllAlerts: Bool = true
    @Published var selectedAlert: AlertRegion?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastAlertedRegionName: String?
    @Published var lastViewedTimestamp: Date?

    private let networkManager = NetworkManager()
    private var refreshTask: Task<Void, Never>?
    private var isFirstFetch: Bool = true
    private var isFirstThreatFetch: Bool = true
    private var isFetching: Bool = false
    private var cancellables = Set<AnyCancellable>()

    private var refreshInterval: Int { 30 }
    
    @Published var isPremium: Bool = UserDefaults.standard.bool(forKey: "premiumEnabled")
    
    var threatServerURL: String {
        "https://sirenua-threatserver.onrender.com"
    }

    private var premiumObserver: NSObjectProtocol? = nil
    private var fcmObserver: NSObjectProtocol? = nil
    private var foregroundObserver: NSObjectProtocol? = nil

    init() {
        vmLogger.info("AlertViewModelV3 initialized")
        initializeRegions()
        setupFCMListener()
        setupRefreshLoop()
        
        // Initial fetch of threat data from server
        Task { await fetchThreatState() }
        
        // Refresh UI when premium status changes (threat details visibility)
        premiumObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let current = UserDefaults.standard.bool(forKey: "premiumEnabled")
                if self.isPremium != current {
                    self.isPremium = current
                }
            }
        }
        
        #if os(iOS)
        // Refresh when app enters foreground (resumes from background)
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            vmLogger.info("App entered foreground — fetching fresh threat state")
            Task { @MainActor in
                await self.fetchThreatState()
            }
        }
        #endif
    }

    deinit {
        refreshTask?.cancel()
        if let premiumObserver {
            NotificationCenter.default.removeObserver(premiumObserver)
        }
        if let fcmObserver {
            NotificationCenter.default.removeObserver(fcmObserver)
        }
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    private func initializeRegions() {
        let regions = [
            ("Вінницька область", 49.2331, 28.4682),
            ("Волинська область", 50.7412, 25.3201),
            ("Дніпропетровська область", 48.4647, 35.0462),
            ("Донецька область", 48.0159, 37.8028),
            ("Житомирська область", 50.2547, 28.6587),
            ("Закарпатська область", 48.6208, 22.2879),
            ("Запорізька область", 47.8388, 35.1396),
            ("Івано-Франківська область", 48.9226, 24.7111),
            ("Київська область", 50.4501, 30.5234),
            ("м. Київ", 50.4501, 30.5234),
            ("Кіровоградська область", 48.5079, 32.2623),
            ("Луганська область", 48.5740, 39.3078),
            ("Львівська область", 49.8397, 24.0297),
            ("Миколаївська область", 46.9750, 31.9946),
            ("Одеська область", 46.4825, 30.7233),
            ("Полтавська область", 49.5883, 34.5514),
            ("Рівненська область", 50.6199, 26.2516),
            ("Сумська область", 50.9077, 34.7981),
            ("Тернопільська область", 49.5535, 25.5948),
            ("Харківська область", 49.9935, 36.2304),
            ("Херсонська область", 46.6354, 32.6169),
            ("Хмельницька область", 49.4230, 26.9871),
            ("Черкаська область", 49.4444, 32.0598),
            ("Чернівецька область", 48.2915, 25.9352),
            ("Чернігівська область", 51.4982, 31.2893)
        ]

        alerts = regions.enumerated().map { index, region in
            AlertRegion(
                id: index,
                name: region.0,
                isActive: false,
                level: 0,
                description: "Немає тривоги",
                coordinate: CLLocationCoordinate2D(latitude: region.1, longitude: region.2)
            )
        }
        updateStats()
    }

    // MARK: - FCM Push Listener
    
    /// Listens for FCM data pushes and triggers an immediate data refresh.
    /// FCM push replaces WebSocket — when server sends push, app fetches fresh state via HTTP.
    private func setupFCMListener() {
        fcmObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("ThreatDataUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            
            // Check if we can apply the push payload directly for instant UI update
            if let userInfo = notification.userInfo,
               let regionName = userInfo["region"] as? String {
                let level = (userInfo["level"] as? String) ?? (userInfo["threat_level"] as? String) ?? "none"
                vmLogger.info("FCM push received for \(regionName) (level: \(level)) — applying instantly")
                
                // Instantly update the local state in memory
                if let index = self.alerts.firstIndex(where: { $0.name == regionName }) {
                    let isAlarmActive = (level != "none")
                    self.alerts[index].isActive = isAlarmActive
                    self.alerts[index].level = isAlarmActive ? 3 : 0
                    self.alerts[index].description = isAlarmActive ? "Повітряна тривога!" : "Немає тривоги"
                    
                    if level == "none" {
                        self.alerts[index].threatLevel = nil
                        self.alerts[index].threatType = nil
                        self.alerts[index].threatDetail = nil
                        self.alerts[index].activeThreats = []
                        self.alerts[index].selectedThreatIndex = 0
                    } else {
                        self.alerts[index].threatLevel = level
                        if let type = userInfo["threat_type"] as? String, !type.isEmpty {
                            self.alerts[index].threatType = type
                        }
                    }
                    self.updateStats()
                }
            }
            
            // Still perform the background fetch to ensure full sync with database/active wave details
            Task { @MainActor in
                await self.fetchThreatState()
            }
        }
    }

    // MARK: - Refresh Loop (HTTP polling every 30s)
    
    private func setupRefreshLoop() {
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(for: .seconds(self.refreshInterval))
                await self.fetchThreatState()
            }
        }
    }

    // MARK: - Fetch Threat State (HTTP — replaces WebSocket)
    
    /// Fetches full threat state from server via GET /api/threats.
    /// Called on: init, every 30s (polling), and on FCM push trigger.
    private func fetchThreatState() async {
        guard !isFetching else { return }
        isFetching = true
        
        do {
            let threats = try await networkManager.fetchThreats(serverURL: threatServerURL)
            applyThreats(threats)
            updateStats()
            updateLastAlertedRegion()
            isFirstThreatFetch = false
        } catch {
            vmLogger.error("Error fetching threats: \(error.localizedDescription)")
            // Fallback: try fetching live alerts from ubilling
            await fetchLiveAlerts()
        }
        
        isFetching = false
    }

    private func applySingleThreat(region: String, threat: ThreatInfo) {
        guard let index = alerts.firstIndex(where: { $0.name == region }) else { return }
        let oldThreatLevel = alerts[index].threatLevel
        let newThreatLevel = threat.level == "none" ? nil : threat.level
        
        alerts[index].threatLevel = newThreatLevel
        alerts[index].threatType = threat.type
        alerts[index].threatDetail = threat.detail
        alerts[index].threatConfidence = threat.confidence
        alerts[index].threatETA = threat.eta
        alerts[index].isThreatPredictive = threat.is_predictive ?? false
        
        // Multi-threat: populate active_threats array
        if let activeThreats = threat.active_threats, !activeThreats.isEmpty {
            alerts[index].activeThreats = activeThreats
            alerts[index].selectedThreatIndex = activeThreats.count - 1 // newest last
        } else {
            alerts[index].activeThreats = []
            alerts[index].selectedThreatIndex = 0
        }
        
        if let isActive = threat.is_active {
            alerts[index].isActive = isActive
            alerts[index].level = isActive ? 3 : 0
            alerts[index].description = isActive ? "Повітряна тривога!" : "Немає тривоги"
        }
        
        if oldThreatLevel == nil && newThreatLevel != nil && !alerts[index].isActive {
            if !isFirstThreatFetch {
                // Фільтрація: не сповіщати про предиктивні загрози з низькою довірою
                let confidence = threat.confidence ?? 75
                let isPredictive = threat.is_predictive ?? false
                if isPredictive && confidence < 50 {
                    vmLogger.info("Skipping notification for predictive low-confidence threat in \(region) (\(confidence)%)")
                    return
                }
                
                let typeDesc = getThreatTypeDescription(threat.type ?? "")
                let title = buildThreatTitle(type: threat.type, confidence: confidence, region: region)
                var body = threat.detail ?? "Виявлено загрозу \(typeDesc)."
                if let eta = threat.eta, !eta.isEmpty {
                    body += " (Час: \(eta))"
                }
                NotificationManager.shared.sendThreatNotification(
                    for: region, title: title, body: body,
                    confidence: confidence, isCritical: confidence >= 85
                )
            }
        }
    }
    
    private func applyThreats(_ threatData: [String: ThreatInfo]) {
        for index in alerts.indices {
            let regionName = alerts[index].name
            guard let threat = threatData[regionName] else { continue }
            
            let oldThreatLevel = alerts[index].threatLevel
            let newThreatLevel = threat.level == "none" ? nil : threat.level
            
            alerts[index].threatLevel = newThreatLevel
            alerts[index].threatType = threat.type
            alerts[index].threatDetail = threat.detail
            alerts[index].threatConfidence = threat.confidence
            alerts[index].threatETA = threat.eta
            alerts[index].isThreatPredictive = threat.is_predictive ?? false
            
            // Multi-threat: populate active_threats array
            if let activeThreats = threat.active_threats, !activeThreats.isEmpty {
                alerts[index].activeThreats = activeThreats
                alerts[index].selectedThreatIndex = activeThreats.count - 1
            } else {
                alerts[index].activeThreats = []
                alerts[index].selectedThreatIndex = 0
            }
            
            if let isActive = threat.is_active {
                alerts[index].isActive = isActive
                alerts[index].level = isActive ? 3 : 0
                alerts[index].description = isActive ? "Повітряна тривога!" : "Немає тривоги"
            }
            
            // Trigger local warning notification if there's a new threat and no active alert
            if oldThreatLevel == nil && newThreatLevel != nil && !alerts[index].isActive {
                if !isFirstThreatFetch {
                    // Фільтрація низької довіри для предиктивних загроз
                    let confidence = threat.confidence ?? 75
                    let isPredictive = threat.is_predictive ?? false
                    if isPredictive && confidence < 50 {
                        vmLogger.info("Skipping notification for predictive low-confidence threat in \(regionName) (\(confidence)%)")
                        continue
                    }
                    
                    let typeDesc = getThreatTypeDescription(threat.type ?? "")
                    let title = buildThreatTitle(type: threat.type, confidence: confidence, region: regionName)
                    var body = threat.detail ?? "Виявлено загрозу \(typeDesc)."
                    if let eta = threat.eta, !eta.isEmpty {
                        body += " (Час: \(eta))"
                    }
                    NotificationManager.shared.sendThreatNotification(
                        for: regionName, title: title, body: body,
                        confidence: confidence, isCritical: confidence >= 85
                    )
                }
            }
        }
        isFirstThreatFetch = false
    }
    
    private func getThreatTypeDescription(_ type: String) -> String {
        switch type {
        case "mig31k":
            return "атаки аеробалістичними ракетами Кинджал"
        case "shahed":
            return "ударних безпілотників Шахед"
        case "cruise_missile":
            return "крилатих ракет"
        case "kab":
            return "ударів керованими авіабомбами (КАБ)"
        case "ballistic":
            return "балістичних ракет"
        default:
            return "повітряної атаки"
        }
    }
    
    /// Builds a threat notification title based on threat type, AI confidence, and target region
    private func buildThreatTitle(type: String?, confidence: Int, region: String) -> String {
        let threatName = type == "mig31k" ? "Авіаційна загроза" : "Виявлено цілі"
        let indicator: String
        if confidence >= 85 {
            indicator = "🔴 Висока ймовірність"
        } else if confidence >= 60 {
            indicator = "🟠 Ймовірна загроза"
        } else {
            indicator = "🟡 Можлива загроза"
        }
        return "\(indicator): \(threatName) (\(region))"
    }
    
    func getThreatTypeDescriptionShort(_ type: String) -> String {
        switch type {
        case "mig31k":
            return "МіГ-31К (Кинджал)"
        case "shahed":
            return "Загроза БпЛА"
        case "cruise_missile":
            return "Крилаті ракети"
        case "kab":
            return "Загроза КАБ"
        case "ballistic":
            return "Балістика"
        default:
            return "Загроза з повітря"
        }
    }
    
    func refreshThreats() {
        Task { await fetchThreatState() }
    }

    private func fetchLiveAlerts() async {
        guard !isFetching else { return }
        isFetching = true
        isLoading = true
        errorMessage = nil

        do {
            let liveData = try await networkManager.fetchLiveAlerts()
            applyLiveAlerts(liveData)
            isFirstFetch = false
            updateStats()
        } catch {
            errorMessage = "Помилка оновлення тривог: \(error.localizedDescription)"
            vmLogger.error("Error fetching alerts: \(error.localizedDescription)")
        }

        isLoading = false
        isFetching = false
    }

    private func applyLiveAlerts(_ liveData: [String: AerialAlertState]) {
        var newlyAlertedRegionName: String?
        
        for index in alerts.indices {
            let regionName = alerts[index].name
            guard let state = liveData[regionName] else { continue }

            let isAlertNow = state.alertnow
            let wasActive = alerts[index].isActive
            alerts[index].isActive = isAlertNow
            alerts[index].level = isAlertNow ? 3 : 0
            alerts[index].description = isAlertNow ? "Повітряна тривога!" : "Немає тривоги"
            alerts[index].lastChanged = state.changed

            guard !isFirstFetch else { continue }
            if !wasActive && isAlertNow {
                NotificationManager.shared.sendAlertNotification(for: regionName)
                newlyAlertedRegionName = regionName
            } else if wasActive && !isAlertNow {
                NotificationManager.shared.sendClearNotification(for: regionName)
            }
        }
        
        if let newRegionName = newlyAlertedRegionName {
            lastAlertedRegionName = newRegionName
            lastViewedTimestamp = nil
        } else if lastAlertedRegionName == nil || !(alerts.first(where: { $0.name == lastAlertedRegionName })?.isActive ?? false) {
            updateLastAlertedRegion()
        }
    }

    func updateLastAlertedRegion() {
        let activeAlerts = alerts.filter { $0.isActive }
        if let last = activeAlerts.max(by: { ($0.lastChanged ?? "") < ($1.lastChanged ?? "") }) {
            if lastAlertedRegionName != last.name {
                lastAlertedRegionName = last.name
                lastViewedTimestamp = nil
            }
        } else {
            lastAlertedRegionName = nil
            lastViewedTimestamp = nil
        }
    }

    func markLastAlertAsViewed() {
        if lastAlertedRegionName != nil && lastViewedTimestamp == nil {
            lastViewedTimestamp = Date()
        }
    }

    private func updateStats() {
        activeAlerts = alerts.filter { $0.isActive }.count
        maxLevel = alerts.filter { $0.isActive }.map { $0.level }.max() ?? 0
    }

    func refreshAlerts() {
        Task { await fetchThreatState() }
    }

    func updateAlertStatus(id: Int, isActive: Bool) {
        // Used for manual testing/overrides if needed
        guard let index = alerts.firstIndex(where: { $0.id == id }) else { return }
        alerts[index].isActive = isActive
        updateStats()
        updateLastAlertedRegion()
    }

    func filterAlerts(by isActive: Bool) {
        showAllAlerts = isActive
    }

    func selectAlert(_ alert: AlertRegion) {
        selectedAlert = alert
    }

    func dismissAlert() {
        selectedAlert = nil
    }

    func getFilteredAlerts() -> [AlertRegion] {
        if showAllAlerts {
            return alerts
        } else {
            return alerts.filter { $0.isActive }
        }
    }

    func getInactiveAlerts() -> [AlertRegion] {
        alerts.filter { !$0.isActive }
    }

    func getActiveAlertsByLevel(_ level: Int) -> [AlertRegion] {
        alerts.filter { $0.isActive && $0.level == level }
    }
}
