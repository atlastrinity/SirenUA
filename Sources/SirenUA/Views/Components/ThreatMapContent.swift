import SwiftUI
import MapKit

struct ThreatMapContent: MapContent {
    let safeRegions: [RegionPolygon]
    let activeThreatRegions: [RegionPolygon]
    let activeAlertRegions: [RegionPolygon]
    let alertsDict: [String: AlertRegion]
    let alerts: [AlertRegion]
    let isPremium: Bool
    let lastAlertedRegionName: String?
    let allFoundShelters: [MKMapItem]
    let selectedShelter: MKMapItem?
    let route: MKRoute?
    let timeRefreshTrigger: Date
    let currentUserCoordinate: CLLocationCoordinate2D
    var zoomScale: CGFloat = 1.0
    let onRegionSelected: (AlertRegion) -> Void

    var flyingThreatAlerts: [AlertRegion] {
        alerts.filter { shouldShowFlyingThreat(for: $0) }
    }
    
    var statusBadgeAlerts: [AlertRegion] {
        alerts.filter { alert in
            if shouldShowFlyingThreat(for: alert) {
                return false
            }
            if alert.isActive { return true }
            if alert.threatLevel == nil && alert.activeThreats.isEmpty { return true }
            if !alert.isActive && alert.threatLevel != nil { return true }
            return false
        }
    }

    var body: some MapContent {
        // Isolated static polygon layer (safe, threat, and active alert region fills)
        RegionPolygonsLayer(
            safeRegions: safeRegions,
            activeThreatRegions: activeThreatRegions,
            activeAlertRegions: activeAlertRegions,
            alertsDict: alertsDict,
            lastAlertedRegionName: lastAlertedRegionName
        )
        
        // User Location Marker
        Annotation("Моє місцезнаходження", coordinate: currentUserCoordinate) {
            Image(systemName: "location.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(6)
                .background(Color.green)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 5)
                .scaleEffect(zoomScale)
                .allowsHitTesting(false)
        }
        
        // Regional threat level, status badges, and flying threat overlays
        ForEach(alerts) { alert in
            if shouldShowFlyingThreat(for: alert) {
                FlyingThreatMapOverlay(
                    alert: alert,
                    isPremium: isPremium,
                    zoomScale: zoomScale,
                    onRegionSelected: onRegionSelected
                )
            } else {
                RegionStatusBadgeAnnotation(
                    alert: alert,
                    timeRefreshTrigger: timeRefreshTrigger,
                    zoomScale: zoomScale,
                    isPremium: isPremium,
                    onRegionSelected: onRegionSelected
                )
            }
        }

        // Nearby shelters markers
        ForEach(allFoundShelters, id: \.self) { shelter in
            let shelterIcon = ShelterType.iconName(for: shelter.name ?? "")
            Marker(shelter.name ?? "Укриття", systemImage: shelterIcon, coordinate: shelter.placemark.coordinate)
                .tint(selectedShelter == shelter ? .green : .cyan)
                .tag(shelter)
        }
        
        // Active GPS Route
        if let route = route {
            MapPolyline(route)
                .stroke(.blue, lineWidth: 5)
        }
    }

    private func shouldShowFlyingThreat(for alert: AlertRegion) -> Bool {
        let isPredictive = alert.isThreatPredictive || (alert.currentThreat?.is_predictive ?? false)
        let hasThreatData = alert.threatType != nil || !alert.activeThreats.isEmpty || (alert.threatDetail != nil && !alert.threatDetail!.isEmpty) || isPredictive
        return (alert.isActive || isPredictive) && hasThreatData
    }
}



// MARK: - Flying Threat Map Overlay MapContent

struct FlyingThreatMapOverlay: MapContent {
    let alert: AlertRegion
    let isPremium: Bool
    var zoomScale: CGFloat = 1.0
    let onRegionSelected: (AlertRegion) -> Void

    var body: some MapContent {
        if !RegionRegistry.isPermanentlyActive(alert.name) {
            let threatType = alert.currentThreat?.type ?? alert.threatType
            let threatLabel = alert.currentThreat?.threatLabel ?? ThreatConstants.title(for: threatType ?? "")
            let confidence = alert.currentThreat?.confidence ?? alert.threatConfidence
            let eta = alert.currentThreat?.dynamicETA ?? alert.displayETA
            let color = alert.color
            let customOrigin = alert.currentThreat?.originCoordinate

            // MARK: - Trajectory flight vector overlay for ALL active threats (gated by Premium)
            if !alert.activeThreats.isEmpty {
                ForEach(alert.activeThreats) { threatItem in
                    let itemType = threatItem.type ?? alert.threatType
                    let itemOrigin = threatItem.originCoordinate
                    let itemColor = threatItem.threatColor
                    PremiumTrajectoryOverlay(
                        targetCoordinate: alert.coordinate,
                        threatType: itemType,
                        customOrigin: itemOrigin,
                        carrierOrigin: threatItem.carrierOriginCoordinate,
                        launchSector: threatItem.launchSectorCoordinate,
                        carrierOriginName: threatItem.carrier_origin_name,
                        launchSectorName: threatItem.launch_sector_name,
                        color: itemColor,
                        isPremium: isPremium
                    )
                }
            } else {
                PremiumTrajectoryOverlay(
                    targetCoordinate: alert.coordinate,
                    threatType: threatType,
                    customOrigin: customOrigin,
                    carrierOrigin: alert.currentThreat?.carrierOriginCoordinate,
                    launchSector: alert.currentThreat?.launchSectorCoordinate,
                    carrierOriginName: alert.currentThreat?.carrier_origin_name,
                    launchSectorName: alert.currentThreat?.launch_sector_name,
                    color: color,
                    isPremium: isPremium
                )
            }

            // Target Region Destination Flying Threat Badge
            Annotation(coordinate: alert.coordinate) {
                FlyingThreatMarkerView(
                    regionName: alert.name,
                    threatType: threatType,
                    threatLabel: threatLabel.isEmpty ? "Загроза" : threatLabel,
                    confidence: confidence,
                    eta: eta,
                    color: color,
                    isPredictive: alert.isThreatPredictive,
                    isPremium: isPremium
                )
                .scaleEffect(zoomScale)
                .onTapGesture {
                    onRegionSelected(alert)
                }
            } label: {
                EmptyView()
            }
        }
    }
}

func threatIconName(for threatType: String?) -> String {
    return ThreatConstants.sfSymbol(for: threatType)
}

// MARK: - Flying Threat Visibility Logic

/// Визначає, чи слід показувати літаючі маркери загроз (БПЛА, ракети, траєкторії).
/// Значок БПЛА/ракети всередині області відображається ВИКЛЮЧНО коли оголошена офіційна тривога (alert.isActive == true).
/// Якщо в області немає тривоги (жовта область) — значок БПЛА всередині області НЕ показується!
func shouldShowFlyingThreat(for alert: AlertRegion) -> Bool {
    let isPredictive = alert.isThreatPredictive || (alert.currentThreat?.is_predictive ?? false)
    let hasThreatData = alert.threatType != nil || !alert.activeThreats.isEmpty || (alert.threatDetail != nil && !alert.threatDetail!.isEmpty) || isPredictive
    return (alert.isActive || isPredictive) && hasThreatData
}


