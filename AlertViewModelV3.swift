import Foundation
import SwiftUI
import CoreLocation

@available(iOS 17.0, *)
@MainActor
class AlertViewModelV3: ObservableObject {
    @Published var alerts: [AlertRegion] = []
    @Published var activeAlerts: Int = 0
    @Published var maxLevel: Int = 0
    @Published var showAllAlerts: Bool = true
    @Published var selectedAlert: AlertRegion?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let networkManager = NetworkManager()
    private var refreshTask: Task<Void, Never>?
    private var isFirstFetch: Bool = true
    private var isFetching: Bool = false

    private var autoRefreshEnabled: Bool {
        UserDefaults.standard.object(forKey: "autoRefreshEnabled") as? Bool ?? true
    }

    private var refreshInterval: Int {
        max(UserDefaults.standard.object(forKey: "refreshInterval") as? Int ?? 30, 15)
    }

    init() {
        initializeRegions()
        refreshAlerts()
        setupRefreshLoop()
    }

    deinit {
        refreshTask?.cancel()
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
            print("Error fetching alerts: \(error)")
        }

        isLoading = false
        isFetching = false
    }

    private func applyLiveAlerts(_ liveData: [String: AerialAlertState]) {
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
            } else if wasActive && !isAlertNow {
                NotificationManager.shared.sendClearNotification(for: regionName)
            }
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
