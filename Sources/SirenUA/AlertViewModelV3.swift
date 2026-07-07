import Foundation
import SwiftUI
import CoreLocation
import Combine
import OSLog

private let vmLogger = Logger(subsystem: "com.sirenua", category: "AlertViewModel")

@available(iOS 16.0, *)
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

    private var autoRefreshEnabled: Bool {
        UserDefaults.standard.object(forKey: "autoRefreshEnabled") as? Bool ?? true
    }

    private var refreshInterval: Int {
        max(UserDefaults.standard.object(forKey: "refreshInterval") as? Int ?? 30, 15)
    }
    
    var isPremium: Bool {
        UserDefaults.standard.object(forKey: "premiumEnabled") as? Bool ?? false
    }
    
    var threatServerURL: String {
        "https://sirenua-threatserver.onrender.com"
    }

    private var premiumObserver: NSObjectProtocol? = nil

    init() {
        vmLogger.info("AlertViewModelV3 initialized")
        initializeRegions()
        refreshAlerts()
        setupRefreshLoop()
        setupWebSocket()
        
        // Instantly refresh threats when premium status changes in UserDefaults
        premiumObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.objectWillChange.send()
                if self.isPremium {
                    ThreatWebSocketClient.shared.connect(to: self.threatServerURL)
                } else {
                    ThreatWebSocketClient.shared.disconnect()
                }
            }
        }
    }

    deinit {
        refreshTask?.cancel()
        if let premiumObserver {
            NotificationCenter.default.removeObserver(premiumObserver)
        }
        ThreatWebSocketClient.shared.disconnect()
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

    private func setupRefreshLoop() {
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(for: .seconds(self.refreshInterval))
                guard self.autoRefreshEnabled else { continue }
                await self.fetchLiveAlerts()
            }
        }
    }

    // setupThreatRefreshLoop has been removed in favor of WebSockets.
    
    private func setupWebSocket() {
        ThreatWebSocketClient.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self, self.isPremium else { return }
                switch event {
                case .initialState(let threats):
                    self.applyThreats(threats)
                case .threatUpdate(let region, let threat):
                    self.applySingleThreat(region: region, threat: threat)
                }
            }
            .store(in: &cancellables)
            
        // If premium, connect automatically
        if isPremium {
            ThreatWebSocketClient.shared.connect(to: threatServerURL)
        }
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
                let title = buildThreatTitle(type: threat.type, confidence: confidence)
                var body = "\(threat.detail ?? "Загроза \(typeDesc)") в \(region)."
                if let eta = threat.eta, !eta.isEmpty {
                    body += " Час: \(eta)"
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
                    let title = buildThreatTitle(type: threat.type, confidence: confidence)
                    var body = "\(threat.detail ?? "Загроза \(typeDesc)") в \(regionName)."
                    if let eta = threat.eta, !eta.isEmpty {
                        body += " Час: \(eta)"
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
    
    /// Builds a threat notification title based on threat type and AI confidence
    private func buildThreatTitle(type: String?, confidence: Int) -> String {
        let threatName = type == "mig31k" ? "Авіаційна загроза" : "Виявлено цілі"
        if confidence >= 85 {
            return "🔴 Висока ймовірність: \(threatName)"
        } else if confidence >= 60 {
            return "🟠 Ймовірна загроза: \(threatName)"
        } else {
            return "🟡 Можлива загроза: \(threatName)"
        }
    }
    
    func refreshThreats() {
        if isPremium {
            ThreatWebSocketClient.shared.disconnect()
            ThreatWebSocketClient.shared.connect(to: threatServerURL)
        }
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
        Task { await fetchLiveAlerts() }
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
