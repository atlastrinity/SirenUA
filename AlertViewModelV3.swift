import Foundation
import SwiftUI
import CoreLocation
import Combine

@available(iOS 17.0, *)
class AlertViewModelV3: ObservableObject {
    @Published var alerts: [AlertRegion] = []
    @Published var activeAlerts: Int = 0
    @Published var maxLevel: Int = 0
    @Published var showAllAlerts: Bool = true
    @Published var selectedAlert: AlertRegion?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: AnyCancellable?
    private let networkManager = NetworkManager()

    init() {
        initializeRegions()
        fetchLiveAlerts()
        setupTimer()
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

    private func setupTimer() {
        refreshTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchLiveAlerts()
            }
    }

    private func fetchLiveAlerts() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            do {
                let liveData = try await networkManager.fetchLiveAlerts()
                
                // Update existing regions based on API response
                for i in 0..<self.alerts.count {
                    let regionName = self.alerts[i].name
                    if let isAlertNow = liveData[regionName] {
                        self.alerts[i].isActive = isAlertNow
                        self.alerts[i].level = isAlertNow ? 3 : 0
                        self.alerts[i].description = isAlertNow ? "Повітряна тривога!" : "Відбій"
                    }
                }
                self.updateStats()
            } catch {
                self.errorMessage = "Помилка оновлення тривог"
                print("Error fetching alerts: \(error)")
            }
            isLoading = false
        }
    }

    private func updateStats() {
        activeAlerts = alerts.filter { $0.isActive }.count
        maxLevel = alerts.filter { $0.isActive }.map { $0.level }.max() ?? 0
    }

    func refreshAlerts() {
        // Called when user manually triggers refresh
        fetchLiveAlerts()
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
