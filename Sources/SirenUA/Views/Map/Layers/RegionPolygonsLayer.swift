import SwiftUI
import MapKit

struct RegionPolygonsLayer: MapContent {
    let safeRegions: [RegionPolygon]
    let activeThreatRegions: [RegionPolygon]
    let activeAlertRegions: [RegionPolygon]
    let alertsDict: [String: AlertRegion]
    let lastAlertedRegionName: String?

    var body: some MapContent {
        // Polygons for safe regions (Clean Deep Midnight Blue with Kyiv-style Cyan Stroke)
        ForEach(safeRegions) { region in
            let strokeColor = Color.cyan.opacity(0.85)
            let strokeWidth: CGFloat = 1.2

            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(strokeColor, lineWidth: strokeWidth)
                    .foregroundStyle(Color(red: 0.04, green: 0.14, blue: 0.38).opacity(0.32))
                    .mapOverlayLevel(level: .aboveRoads)
            }
        }

        // Polygons for threat zones (Vibrant Juicy Yellow / Orange Glow)
        ForEach(activeThreatRegions) { region in
            let threatColor = alertsDict[region.nameUK]?.color ?? .yellow
            let fillColor: Color = threatColor.opacity(0.62)
            let strokeWidth: CGFloat = 1.2

            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(threatColor.opacity(0.95), lineWidth: strokeWidth)
                    .foregroundStyle(fillColor)
                    .mapOverlayLevel(level: .aboveRoads)
            }
        }

        // Polygons for official active alert regions (Vivid Bright Red Glow)
        ForEach(activeAlertRegions) { region in
            let isLastAlerted = region.nameUK == lastAlertedRegionName
            let redFill = isLastAlerted ? Color(red: 0.96, green: 0.11, blue: 0.16).opacity(0.68) : Color(red: 0.91, green: 0.13, blue: 0.19).opacity(0.58)
            let strokeWidth: CGFloat = 1.2

            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(Color.red.opacity(0.95), lineWidth: strokeWidth)
                    .foregroundStyle(redFill)
                    .mapOverlayLevel(level: .aboveRoads)
            }
        }
    }
}
