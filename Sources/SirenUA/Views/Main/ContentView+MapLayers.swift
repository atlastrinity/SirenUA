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
        geoManager.regions.filter { region in
            alertsDict[region.nameUK]?.isActive == true
        }
    }

    var activeThreatRegions: [RegionPolygon] {
        guard viewModel.isPremium else { return [] }
        return geoManager.regions.filter { region in
            guard let alert = alertsDict[region.nameUK] else { return false }
            return !alert.isActive && alert.threatLevel != nil
        }
    }

    var safeRegions: [RegionPolygon] {
        geoManager.regions.filter { region in
            guard let alert = alertsDict[region.nameUK] else { return true }
            return !alert.isActive && (alert.threatLevel == nil || !viewModel.isPremium)
        }
    }
}
