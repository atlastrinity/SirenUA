import SwiftUI
import MapKit

struct RegionPolygonsLayer: MapContent {
    let safeRegions: [RegionPolygon]
    let activeThreatRegions: [RegionPolygon]
    let activeAlertRegions: [RegionPolygon]
    let alertsDict: [String: AlertRegion]
    let lastAlertedRegionName: String?

    var body: some MapContent {
        let thinStrokeWidth: CGFloat = 0.85

        // =========================================================================
        // PASS 1: REGION BACKGROUND FILLS (No Strokes)
        // =========================================================================

        // Fills for safe regions
        ForEach(safeRegions) { region in
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .foregroundStyle(Color(red: 0.04, green: 0.14, blue: 0.38).opacity(0.32))
                    .mapOverlayLevel(level: .aboveRoads)
            }
        }

        // Fills for threat zones
        ForEach(activeThreatRegions) { region in
            let threatColor = alertsDict[region.nameUK]?.color ?? .yellow
            let fillColor: Color = threatColor.opacity(0.62)
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .foregroundStyle(fillColor)
                    .mapOverlayLevel(level: .aboveRoads)
            }
        }

        // Fills for official active alert regions
        ForEach(activeAlertRegions) { region in
            let isLastAlerted = region.nameUK == lastAlertedRegionName
            let redFill = isLastAlerted ? Color(red: 0.96, green: 0.11, blue: 0.16).opacity(0.68) : Color(red: 0.91, green: 0.13, blue: 0.19).opacity(0.58)
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .foregroundStyle(redFill)
                    .mapOverlayLevel(level: .aboveRoads)
            }
        }

        // =========================================================================
        // PASS 2: BORDER STROKES (Strict Priority: Blue (3) -> Yellow (2) -> Red (1))
        // =========================================================================

        // Priority 3 (Lowest): Safe Regions Border Strokes (Cyan / Blue)
        ForEach(safeRegions) { region in
            let strokeColor = Color.cyan.opacity(0.70)
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(strokeColor, lineWidth: thinStrokeWidth)
                    .mapOverlayLevel(level: .aboveRoads)
            }
        }

        // Priority 2 (Medium): Threat Zones Border Strokes (Yellow / Orange - overwrites Blue)
        ForEach(activeThreatRegions) { region in
            let threatColor = alertsDict[region.nameUK]?.color ?? .yellow
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(threatColor.opacity(0.95), lineWidth: thinStrokeWidth)
                    .mapOverlayLevel(level: .aboveRoads)
            }
        }

        // Priority 1 (Highest): Active Alert Regions Border Strokes (Vivid Red - overwrites Yellow & Blue)
        ForEach(activeAlertRegions) { region in
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(Color.red.opacity(0.95), lineWidth: thinStrokeWidth)
                    .mapOverlayLevel(level: .aboveRoads)
            }
        }
    }
}
