import SwiftUI
import MapKit

// MARK: - Theme & Status Computed Properties
extension ContentView {

    // MARK: Filter helpers

    func isRegionFiltered(_ name: String) -> Bool {
        let shared = UserDefaults(suiteName: "group.com.sirenua.shared")
        let allTracked = shared?.object(forKey: "allRegionsTracked") as? Bool ?? true
        let trackedString = shared?.string(forKey: "trackedRegionsString") ?? ""
        let trackedList = trackedString.components(separatedBy: ";").filter { !$0.isEmpty }
        return allTracked || trackedList.contains(name)
    }

    var activeTrackedAlerts: [AlertRegion] {
        viewModel.alerts.filter { $0.isActive && isRegionFiltered($0.name) }
    }

    var activeTrackedThreats: [AlertRegion] {
        guard viewModel.isPremium else { return [] }
        return viewModel.alerts.filter { !($0.isActive) && $0.threatLevel != nil && isRegionFiltered($0.name) }
    }

    // MARK: Derived state flags

    var hasAlerts: Bool { !activeTrackedAlerts.isEmpty }
    var hasThreats: Bool { !activeTrackedThreats.isEmpty }

    // MARK: Theme values

    var themeColor: Color {
        if hasAlerts {
            return .red
        } else if hasThreats {
            if activeTrackedThreats.contains(where: { $0.color == .red }) {
                return .red
            } else if activeTrackedThreats.contains(where: { $0.color == .orange }) {
                return .orange
            } else {
                return .yellow
            }
        } else {
            return .green
        }
    }

    var themeActiveCount: Int {
        hasAlerts ? activeTrackedAlerts.count : (hasThreats ? activeTrackedThreats.count : 0)
    }

    var themeStatusText: String {
        hasAlerts ? "ТРИВОГА" : (hasThreats ? "ЗАГРОЗА" : "СПОКІЙНО")
    }
}
