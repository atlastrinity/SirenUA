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
    let getThreatTypeDescriptionShort: (String) -> String
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
                    zoomScale: zoomScale,
                    getThreatTypeDescriptionShort: getThreatTypeDescriptionShort,
                    onRegionSelected: onRegionSelected
                )
            } else {
                RegionStatusBadgeAnnotation(
                    alert: alert,
                    timeRefreshTrigger: timeRefreshTrigger,
                    zoomScale: zoomScale,
                    getThreatTypeDescriptionShort: getThreatTypeDescriptionShort,
                    onRegionSelected: onRegionSelected
                )
            }
        }

        // Nearby shelters markers
        ForEach(allFoundShelters, id: \.self) { shelter in
            Marker(shelter.name ?? "Укриття", systemImage: "figure.walk.arrival", coordinate: shelter.placemark.coordinate)
                .tint(selectedShelter == shelter ? .green : .blue)
                .tag(shelter)
        }
        
        // Active GPS Route
        if let route = route {
            MapPolyline(route)
                .stroke(.blue, lineWidth: 5)
        }
    }
}



// MARK: - Flying Threat Map Overlay MapContent

struct FlyingThreatMapOverlay: MapContent {
    let alert: AlertRegion
    var zoomScale: CGFloat = 1.0
    let getThreatTypeDescriptionShort: (String) -> String
    let onRegionSelected: (AlertRegion) -> Void

    var body: some MapContent {
        let threatType = alert.currentThreat?.type ?? alert.threatType
        let threatLabel = alert.currentThreat?.threatLabel ?? getThreatTypeDescriptionShort(threatType ?? "")
        let confidence = alert.currentThreat?.confidence ?? alert.threatConfidence
        let eta = alert.currentThreat?.dynamicETA ?? alert.displayETA
        let color = alert.color
        let customOrigin = alert.currentThreat?.originCoordinate
        let trajectory = calculateTrajectory(target: alert.coordinate, threatType: threatType, customOrigin: customOrigin)

        // MARK: - Tapering Tail (3-Layer Streamlined GPU Render)
        let n = trajectory.fullPoints.count

        // 1. Wide Diffuse Outer Glow Tail (0%→70%)
        MapPolyline(coordinates: Array(trajectory.fullPoints.prefix(max(2, n * 70 / 100))))
            .stroke(
                color.opacity(0.22),
                style: StrokeStyle(lineWidth: 11.0, lineCap: .round, lineJoin: .round)
            )
            .mapOverlayLevel(level: .aboveLabels)

        // 2. High-Contrast Core Trajectory Line (0%→100%)
        MapPolyline(coordinates: trajectory.fullPoints)
            .stroke(
                Color(red: 1.0, green: 0.92, blue: 0.0).opacity(0.95),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
            .mapOverlayLevel(level: .aboveLabels)

        // 3. Focused White Hot-Spot Target Head (35%→100%)
        MapPolyline(coordinates: Array(trajectory.fullPoints.suffix(max(2, n * 35 / 100))))
            .stroke(
                Color.white.opacity(0.92),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
            .mapOverlayLevel(level: .aboveLabels)

        // 6. Intermediate Detection Checkpoint Threat Object Badge
        Annotation(coordinate: trajectory.lastCheckpointCoordinate) {
            TrajectoryFlowChevronView(
                angle: trajectory.lastCheckpointAngle,
                threatIcon: threatIconName(for: threatType),
                threatLabel: threatLabel.isEmpty ? "Виявлено" : threatLabel,
                opacity: 0.95
            )
            .scaleEffect(zoomScale)
            .allowsHitTesting(false)
        } label: {
            EmptyView()
        }

        // 7. Target Region Destination Flying Threat Badge
        Annotation(coordinate: alert.coordinate) {
            FlyingThreatMarkerView(
                regionName: alert.name,
                threatType: threatType,
                threatLabel: threatLabel.isEmpty ? "Загроза" : threatLabel,
                confidence: confidence,
                eta: eta,
                color: color,
                isPredictive: alert.isThreatPredictive
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


