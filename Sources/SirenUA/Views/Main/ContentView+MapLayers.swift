import SwiftUI
import MapKit

// MARK: - Map Layers Computed Properties
extension ContentView {

    var selectedMapStyle: MapStyle {
        switch mapType {
        case 1:  return .hybrid
        case 2:  return .imagery
        default: return .standard(elevation: .realistic)
        }
    }

    var alertsDict: [String: AlertRegion] {
        Dictionary(uniqueKeysWithValues: viewModel.alerts.map { ($0.name, $0) })
    }

    var activeAlertRegions: [RegionPolygon] {
        geoManager.regions
            .filter { alertsDict[$0.nameUK]?.isActive == true }
            .sorted { r1, r2 in
                if r1.nameUK == "м. Київ" { return false }
                if r2.nameUK == "м. Київ" { return true }
                return r1.nameUK < r2.nameUK
            }
    }

    var activeThreatRegions: [RegionPolygon] {
        geoManager.regions
            .filter { region in
                guard let alert = alertsDict[region.nameUK] else { return false }
                return !alert.isActive && (alert.threatLevel != nil || !alert.activeThreats.isEmpty)
            }
            .sorted { r1, r2 in
                if r1.nameUK == "м. Київ" { return false }
                if r2.nameUK == "м. Київ" { return true }
                return r1.nameUK < r2.nameUK
            }
    }

    var safeRegions: [RegionPolygon] {
        geoManager.regions
            .filter { region in
                guard let alert = alertsDict[region.nameUK] else { return true }
                return !alert.isActive && alert.threatLevel == nil && alert.activeThreats.isEmpty
            }
            .sorted { r1, r2 in
                if r1.nameUK == "м. Київ" { return false }
                if r2.nameUK == "м. Київ" { return true }
                return r1.nameUK < r2.nameUK
            }
    }
}
