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
    let getThreatTypeDescriptionShort: (String) -> String
    let onRegionSelected: (AlertRegion) -> Void

    var body: some MapContent {
        // Polygons for safe regions (Green)
        ForEach(safeRegions) { region in
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(.green.opacity(0.35), lineWidth: 0.5)
                    .foregroundStyle(.green.opacity(0.06))
            }
        }

        // Polygons for threat zones (Yellow / Orange)
        ForEach(activeThreatRegions) { region in
            let threatColor = alertsDict[region.nameUK]?.color ?? .yellow
            let confidence = alertsDict[region.nameUK]?.threatConfidence ?? 75
            let strokeOpacity: Double = confidence >= 85 ? 0.95 : (confidence >= 60 ? 0.8 : 0.65)
            let fillOpacity: Double = confidence >= 85 ? 0.6 : (confidence >= 60 ? 0.45 : 0.3)
            let strokeColor: Color = threatColor.opacity(strokeOpacity)
            let fillColor: Color = threatColor.opacity(fillOpacity)
            
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(strokeColor, lineWidth: 0.5)
                    .foregroundStyle(fillColor)
            }
        }

        // Polygons for official active alert regions (Red)
        ForEach(activeAlertRegions) { region in
            let isLastAlerted = region.nameUK == lastAlertedRegionName
            
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(.red.opacity(0.6), lineWidth: 0.7)
                    .foregroundStyle(isLastAlerted ? .red.opacity(0.5) : .red.opacity(0.35))
            }
        }
        
        // User current location marker
        Annotation("Ви", coordinate: currentUserCoordinate) {
            Image(systemName: "location.north.fill")
                .foregroundColor(.white)
                .padding(8)
                .background(Color.green)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 5)
        }
        
        // Regional threat level and status badges (All regions, including safe green ones)
        ForEach(alerts) { alert in
            let isThreatActive = !alert.isActive && alert.threatLevel != nil && isPremium
            let badgeIcon: String = alert.isActive ? "exclamationmark.triangle.fill" : (isThreatActive ? alert.icon : "checkmark.circle.fill")
            let badgeBgColor: Color = alert.isActive ? .red : (isThreatActive ? alert.color : .green)

            Annotation(coordinate: alert.coordinate) {
                VStack(spacing: 4) {
                    Button(action: {
                        onRegionSelected(alert)
                    }) {
                        Image(systemName: badgeIcon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(badgeBgColor)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                            .shadow(radius: 3)
                    }
                    
                    VStack(spacing: 1) {
                        let _ = timeRefreshTrigger
                        Text(alert.name)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                        
                        if isThreatActive, let type = alert.threatType {
                            Text(getThreatTypeDescriptionShort(type))
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.yellow)
                                .lineLimit(1)
                                .multilineTextAlignment(.center)
                        }
                        
                        if isThreatActive {
                            HStack(spacing: 3) {
                                if let conf = alert.threatConfidence {
                                    Text("⚙️ \(conf)%")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(conf >= 85 ? .red : (conf >= 60 ? .orange : .yellow))
                                }
                                if let eta = alert.displayETA, !eta.isEmpty {
                                    Text(eta)
                                        .font(.system(size: 7, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        } else if !alert.isActive {
                            Text("Без тривоги")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.green.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(badgeBgColor.opacity(0.3), lineWidth: 0.5)
                    )
                }
            } label: {
                EmptyView()
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
