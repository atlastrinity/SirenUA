import Foundation

// MARK: - AlertViewModelV3 Public Query/Filter Helpers
extension AlertViewModelV3 {

    func updateLastAlertedRegion() {
        let active = alerts.filter { $0.isActive && !RegionRegistry.isPermanentlyActive($0.name) }
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
        let activeList = alerts.filter { $0.isActive && !RegionRegistry.isPermanentlyActive($0.name) }
        activeAlerts = activeList.count
        maxLevel = activeList.map { $0.level }.max() ?? 0
    }

    func refreshAlerts() {
        Task { await fetchThreatState() }
    }

    func updateAlertStatus(id: Int, isActive: Bool) {
        guard let index = alerts.firstIndex(where: { $0.id == id }) else { return }
        alerts[index].isActive = isActive
        updateStats()
        updateLastAlertedRegion()
    }

    func getFilteredAlerts() -> [AlertRegion] {
        let base = alerts.filter { !RegionRegistry.isPermanentlyActive($0.name) }
        return showAllAlerts ? base : base.filter { $0.isActive }
    }

    func getThreatTypeDescriptionShort(_ type: String) -> String {
        ThreatConstants.title(for: type)
    }
}
