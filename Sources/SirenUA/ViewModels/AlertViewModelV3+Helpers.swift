import Foundation

// MARK: - AlertViewModelV3 Public Query/Filter Helpers
extension AlertViewModelV3 {

    func updateLastAlertedRegion() {
        let active = alerts.filter { $0.isActive }
        if let last = active.max(by: { ($0.lastChanged ?? "") < ($1.lastChanged ?? "") }) {
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

    func updateStats() {
        activeAlerts = alerts.filter { $0.isActive }.count
        maxLevel = alerts.filter { $0.isActive }.map { $0.level }.max() ?? 0
    }

    func refreshAlerts() {
        Task { await fetchThreatState() }
    }

    func refreshThreats() {
        Task { await fetchThreatState() }
    }

    func updateAlertStatus(id: Int, isActive: Bool) {
        guard let index = alerts.firstIndex(where: { $0.id == id }) else { return }
        alerts[index].isActive = isActive
        updateStats()
        updateLastAlertedRegion()
    }

    func filterAlerts(by isActive: Bool) { showAllAlerts = isActive }
    func selectAlert(_ alert: AlertRegion) { selectedAlert = alert }
    func dismissAlert() { selectedAlert = nil }

    func getFilteredAlerts() -> [AlertRegion] {
        showAllAlerts ? alerts : alerts.filter { $0.isActive }
    }

    func getInactiveAlerts() -> [AlertRegion] {
        alerts.filter { !$0.isActive }
    }

    func getActiveAlertsByLevel(_ level: Int) -> [AlertRegion] {
        alerts.filter { $0.isActive && $0.level == level }
    }

    func getThreatTypeDescriptionShort(_ type: String) -> String {
        ThreatConstants.title(for: type)
    }
}
