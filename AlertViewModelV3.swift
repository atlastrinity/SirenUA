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

    init() {
        loadInitialData()
    }

    private func loadInitialData() {
        // Generate test alerts for major Ukrainian cities
        let cities = [
            ("Київська область", 50.4501, 30.5234),
            ("Львівська область", 49.8397, 24.0297),
            ("Одеська область", 46.4825, 30.7233),
            ("Харківська область", 49.9935, 36.2304),
            ("Дніпропетровська область", 48.4647, 35.0462),
            ("Запорізька область", 47.8580, 35.1428)
        ]

        for (name, lat, lon) in cities {
            let isActive = Bool.random()
            let level = isActive ? Int.random(in: 1...4) : 0
            let description = isActive ? "Повітряна тривога: $level рівень небезпеки" : "Тривога минула"

            alerts.append(AlertRegion(
                id: Int.random(in: 1...10000),
                name: name,
                isActive: isActive,
                level: level,
                description: description,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)
            ))
        }

        updateStats()
    }

    func updateAlertStatus(id: Int, isActive: Bool) {
        guard let index = alerts.firstIndex(where: { $0.id == id }) else { return }
        alerts[index].isActive = isActive
        updateStats()
    }

    private func updateStats() {
        activeAlerts = alerts.filter { $0.isActive }.count
        maxLevel = alerts.filter { $0.isActive }.map { $0.level }.max() ?? 0
    }

    func refreshAlerts() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.loadInitialData()
            self.isLoading = false
        }
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


