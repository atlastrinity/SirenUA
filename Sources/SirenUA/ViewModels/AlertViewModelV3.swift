import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import CoreLocation
import Combine
import OSLog

let vmLogger = Logger(subsystem: "com.sirenua", category: "AlertViewModel")

// MARK: - AlertViewModelV3
// Logic extensions live in ViewModels/:
//   AlertViewModelV3+Threats.swift  — fetchThreatState, applyThreats, fetchLiveAlerts, applyLiveAlerts
//   AlertViewModelV3+Helpers.swift  — updateStats, markLastAlertAsViewed, getFilteredAlerts, getThreatTypeDescriptionShort …

@MainActor
final class AlertViewModelV3: ObservableObject {
    @Published var alerts: [AlertRegion] = []
    @Published var activeAlerts: Int = 0
    @Published var maxLevel: Int = 0
    @Published var showAllAlerts: Bool = true
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastAlertedRegionName: String?
    @Published var lastViewedTimestamp: Date?
    @Published var isPremium: Bool = PremiumGatekeeper.shared.isPremium

    let networkManager = NetworkManager()
    var refreshTask: Task<Void, Never>?
    var isFirstFetch: Bool = true
    var isFirstThreatFetch: Bool = true
    var isFetching: Bool = false
    var firstNetworkFailureDate: Date? = nil
    var cancellables = Set<AnyCancellable>()

    var refreshInterval: Int { 30 }

    var threatServerURL: String {
        NetworkManager.serverURL
    }

    var fcmObserver: NSObjectProtocol? = nil
    var foregroundObserver: NSObjectProtocol? = nil

    // MARK: - Init

    init() {
        vmLogger.info("AlertViewModelV3 initialized")
        initializeRegions()
        setupFCMListener()
        setupRefreshLoop()

        Task { await fetchThreatState() }

        PremiumGatekeeper.shared.$isPremium
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                if self?.isPremium != status {
                    self?.isPremium = status
                }
            }
            .store(in: &cancellables)

        #if os(iOS)
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            vmLogger.info("App entered foreground — fetching fresh threat state")
            Task { @MainActor in await self.fetchThreatState() }
        }
        #endif
    }

    deinit {
        refreshTask?.cancel()
        if let fcmObserver     { NotificationCenter.default.removeObserver(fcmObserver) }
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
    }

    // MARK: - Private Setup

    private func initializeRegions() {
        let regions: [(String, Double, Double)] = [
            ("Вінницька область",         49.2331, 28.4682),
            ("Волинська область",          50.7412, 25.3201),
            ("Дніпропетровська область",   48.4647, 35.0462),
            ("Донецька область",           48.0159, 37.8028),
            ("Житомирська область",        50.2547, 28.6587),
            ("Закарпатська область",       48.6208, 22.2879),
            ("Запорізька область",         47.8388, 35.1396),
            ("Івано-Франківська область",  48.9226, 24.7111),
            ("Київська область",           50.0500, 30.1500),
            ("м. Київ",                    50.4501, 30.5234),
            ("Кіровоградська область",     48.5079, 32.2623),
            ("Луганська область",          48.5740, 39.3078),
            ("Львівська область",          49.8397, 24.0297),
            ("Миколаївська область",       46.9750, 31.9946),
            ("Одеська область",            46.4825, 30.7233),
            ("Полтавська область",         49.5883, 34.5514),
            ("Рівненська область",         50.6199, 26.2516),
            ("Сумська область",            50.9077, 34.7981),
            ("Тернопільська область",      49.5535, 25.5948),
            ("Харківська область",         49.9935, 36.2304),
            ("Херсонська область",         46.6354, 32.6169),
            ("Хмельницька область",        49.4230, 26.9871),
            ("Черкаська область",          49.4444, 32.0598),
            ("Чернівецька область",        48.2915, 25.9352),
            ("Чернігівська область",       51.4982, 31.2893)
        ]
        alerts = regions.enumerated().map { index, region in
            let isPermActive = RegionRegistry.isPermanentlyActive(region.0)
            return AlertRegion(
                id: index,
                name: region.0,
                isActive: isPermActive,
                level: isPermActive ? 3 : 0,
                description: isPermActive ? "Тимчасово окупована територія" : "Немає тривоги",
                coordinate: CLLocationCoordinate2D(latitude: region.1, longitude: region.2)
            )
        }

        // Крим — тимчасово окупована територія, завжди червона
        let crimeaIndex = alerts.count
        alerts.append(AlertRegion(
            id: crimeaIndex,
            name: "Автономна Республіка Крим",
            isActive: true,
            level: 3,
            description: "Тимчасово окупована територія",
            coordinate: CLLocationCoordinate2D(latitude: 44.9521, longitude: 34.1024)
        ))

        updateStats()
    }

    private func setupFCMListener() {
        fcmObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("ThreatDataUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            Task { @MainActor in
                if let userInfo = notification.userInfo {
                    let regionName = (userInfo["region"] as? String)
                                  ?? (userInfo["regionName"] as? String)
                                  ?? ""
                    let level = (userInfo["level"] as? String)
                             ?? (userInfo["threat_level"] as? String)
                             ?? "none"
                    let status = (userInfo["status"] as? String) ?? ""
                    let action = (userInfo["action"] as? String) ?? ""
                    let isClear = status == "clear" || status == "off" || action == "clear" || level == "none" || level == "clear"
                    let isOfficialAlarmVal = (userInfo["is_official_alarm"] as? Bool)
                                   ?? ((userInfo["is_official_alarm"] as? String) == "true" || (userInfo["is_official_alarm"] as? String) == "1")

                    if !regionName.isEmpty {
                        vmLogger.info("FCM push received for \(regionName) (level: \(level), status: \(status), isClear: \(isClear)) — applying instantly")

                        if let index = self.alerts.firstIndex(where: { $0.name == regionName }) {
                            if isClear {
                                self.alerts[index].isActive = false
                                self.alerts[index].threatLevel = nil
                                self.alerts[index].threatType = nil
                                self.alerts[index].threatDetail = nil
                                self.alerts[index].activeThreats = []
                                self.alerts[index].selectedThreatIndex = 0
                            } else {
                                if isOfficialAlarmVal {
                                    self.alerts[index].isActive = true
                                }
                                self.alerts[index].threatLevel = level
                                if let type = userInfo["threat_type"] as? String, !type.isEmpty {
                                    self.alerts[index].threatType = type
                                }
                            }
                            self.updateStats()
                        }
                    }
                }
                // Always fetch authoritative state from server immediately
                await self.fetchThreatState()
            }
        }
    }

    private func setupRefreshLoop() {
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(for: .seconds(self.refreshInterval))
                await self.fetchThreatState()
            }
        }
    }
}
