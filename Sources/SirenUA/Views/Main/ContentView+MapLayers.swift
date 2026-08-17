import SwiftUI
import MapKit

// MARK: - Map Layers Computed Properties
extension ContentView {

    var selectedMapStyle: MapStyle {
        switch mapType {
        case 1:  return .imagery(elevation: .flat)
        case 2:  return .hybrid(elevation: .flat)
        default: return .standard(elevation: .flat)
        }
    }

    var alertsDict: [String: AlertRegion] {
        if !viewModel.alertsDict.isEmpty {
            return viewModel.alertsDict
        }
        return Dictionary(uniqueKeysWithValues: viewModel.alerts.map { ($0.name, $0) })
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
        YellowZonePolicy.filterActiveThreatRegions(
            allRegions: geoManager.regions,
            alertsDict: alertsDict,
            isPremium: viewModel.isPremium
        )
    }

    var safeRegions: [RegionPolygon] {
        YellowZonePolicy.filterSafeRegions(
            allRegions: geoManager.regions,
            alertsDict: alertsDict,
            isPremium: viewModel.isPremium
        )
    }
}
