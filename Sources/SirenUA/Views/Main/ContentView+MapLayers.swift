import SwiftUI
import MapKit

// MARK: - High-Performance Region Layers Cache

@MainActor
final class RegionLayersCache {
    static let shared = RegionLayersCache()

    private var cachedKey: String = ""
    private var cachedAlertsDict: [String: AlertRegion] = [:]
    private var cachedActiveAlerts: [RegionPolygon] = []
    private var cachedActiveThreats: [RegionPolygon] = []
    private var cachedSafeRegions: [RegionPolygon] = []

    func getLayers(
        alerts: [AlertRegion],
        alertsDict: [String: AlertRegion],
        geoRegions: [RegionPolygon],
        isPremium: Bool
    ) -> (
        alertsDict: [String: AlertRegion],
        activeAlerts: [RegionPolygon],
        activeThreats: [RegionPolygon],
        safeRegions: [RegionPolygon]
    ) {
        let key = makeFootprint(alerts: alerts, isPremium: isPremium, geoCount: geoRegions.count)
        if key == cachedKey && !cachedAlertsDict.isEmpty {
            return (cachedAlertsDict, cachedActiveAlerts, cachedActiveThreats, cachedSafeRegions)
        }

        let dict = !alertsDict.isEmpty ? alertsDict : Dictionary(uniqueKeysWithValues: alerts.map { ($0.name, $0) })
        let activeAlerts = geoRegions
            .filter { dict[$0.nameUK]?.isActive == true }
            .sorted { r1, r2 in
                if r1.nameUK == "м. Київ" { return false }
                if r2.nameUK == "м. Київ" { return true }
                return r1.nameUK < r2.nameUK
            }

        let activeThreats = YellowZonePolicy.filterActiveThreatRegions(
            allRegions: geoRegions,
            alertsDict: dict,
            isPremium: isPremium
        )

        let safe = YellowZonePolicy.filterSafeRegions(
            allRegions: geoRegions,
            alertsDict: dict,
            isPremium: isPremium
        )

        cachedKey = key
        cachedAlertsDict = dict
        cachedActiveAlerts = activeAlerts
        cachedActiveThreats = activeThreats
        cachedSafeRegions = safe

        return (dict, activeAlerts, activeThreats, safe)
    }

    private func makeFootprint(alerts: [AlertRegion], isPremium: Bool, geoCount: Int) -> String {
        var hasher = Hasher()
        hasher.combine(isPremium)
        hasher.combine(geoCount)
        for alert in alerts {
            hasher.combine(alert.name)
            hasher.combine(alert.isActive)
            hasher.combine(alert.activeDistricts)
            hasher.combine(alert.threatLevel)
            hasher.combine(alert.activeThreats.count)
        }
        return String(hasher.finalize())
    }
}

// MARK: - Map Layers Computed Properties
extension ContentView {

    var selectedMapStyle: MapStyle {
        switch mapType {
        case 1:  return .imagery(elevation: .flat)
        case 2:  return .hybrid(elevation: .flat)
        default: return .standard(elevation: .flat)
        }
    }

    private var cachedLayers: (
        alertsDict: [String: AlertRegion],
        activeAlerts: [RegionPolygon],
        activeThreats: [RegionPolygon],
        safeRegions: [RegionPolygon]
    ) {
        RegionLayersCache.shared.getLayers(
            alerts: viewModel.alerts,
            alertsDict: viewModel.alertsDict,
            geoRegions: geoManager.regions,
            isPremium: viewModel.isPremium
        )
    }

    var alertsDict: [String: AlertRegion] {
        cachedLayers.alertsDict
    }

    var activeAlertRegions: [RegionPolygon] {
        cachedLayers.activeAlerts
    }

    var activeThreatRegions: [RegionPolygon] {
        cachedLayers.activeThreats
    }

    var safeRegions: [RegionPolygon] {
        cachedLayers.safeRegions
    }
}
