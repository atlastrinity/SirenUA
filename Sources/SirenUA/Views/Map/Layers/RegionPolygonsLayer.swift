import SwiftUI
import MapKit
import CoreLocation

struct BorderPolyline: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}

// MARK: - High-Performance Cached Border Lines Generator

@MainActor
private final class BorderLinesCache {
    static let shared = BorderLinesCache()
    private var cachedKey: String = ""
    private var cachedLines: [BorderPolyline] = []

    func getLines(
        activeAlertRegions: [RegionPolygon],
        activeThreatRegions: [RegionPolygon],
        safeRegions: [RegionPolygon],
        alertsDict: [String: AlertRegion]
    ) -> [BorderPolyline] {
        let key = makeFootprint(
            activeAlertRegions: activeAlertRegions,
            activeThreatRegions: activeThreatRegions,
            safeRegions: safeRegions,
            alertsDict: alertsDict
        )
        if key == cachedKey && !cachedLines.isEmpty {
            return cachedLines
        }

        let lines = computeLines(
            activeAlertRegions: activeAlertRegions,
            activeThreatRegions: activeThreatRegions,
            safeRegions: safeRegions,
            alertsDict: alertsDict
        )
        cachedKey = key
        cachedLines = lines
        return lines
    }

    private func makeFootprint(
        activeAlertRegions: [RegionPolygon],
        activeThreatRegions: [RegionPolygon],
        safeRegions: [RegionPolygon],
        alertsDict: [String: AlertRegion]
    ) -> String {
        let a = activeAlertRegions.map(\.nameUK).joined(separator: ",")
        let t = activeThreatRegions.map { "\($0.nameUK)_\(alertsDict[$0.nameUK]?.threatLevel ?? "")" }.joined(separator: ",")
        return "\(a)|\(t)|\(safeRegions.count)"
    }

    private func computeLines(
        activeAlertRegions: [RegionPolygon],
        activeThreatRegions: [RegionPolygon],
        safeRegions: [RegionPolygon],
        alertsDict: [String: AlertRegion]
    ) -> [BorderPolyline] {
        var result: [BorderPolyline] = []
        result.reserveCapacity(48)

        // Priority 1: Active Alert Regions (Vivid Red)
        for (rIdx, region) in activeAlertRegions.enumerated() {
            let color = Color.red.opacity(0.95)
            for (pIdx, polyCoords) in region.polygons.enumerated() {
                guard polyCoords.count >= 2 else { continue }
                result.append(BorderPolyline(id: "red_\(rIdx)_\(pIdx)", coordinates: polyCoords, color: color))
            }
        }

        // Priority 2: Active Threat Regions (Yellow / Orange)
        for (rIdx, region) in activeThreatRegions.enumerated() {
            let threatColor = alertsDict[region.nameUK]?.color ?? .yellow
            let color = threatColor.opacity(0.95)
            for (pIdx, polyCoords) in region.polygons.enumerated() {
                guard polyCoords.count >= 2 else { continue }
                result.append(BorderPolyline(id: "yellow_\(rIdx)_\(pIdx)", coordinates: polyCoords, color: color))
            }
        }

        // Priority 3: Safe Regions (Cyan / Blue)
        let cyanColor = Color.cyan.opacity(0.85)
        for (rIdx, region) in safeRegions.enumerated() {
            for (pIdx, polyCoords) in region.polygons.enumerated() {
                guard polyCoords.count >= 2 else { continue }
                result.append(BorderPolyline(id: "cyan_\(rIdx)_\(pIdx)", coordinates: polyCoords, color: cyanColor))
            }
        }

        return result
    }
}

// MARK: - RegionPolygonsLayer

struct RegionPolygonsLayer: MapContent {
    let safeRegions: [RegionPolygon]
    let activeThreatRegions: [RegionPolygon]
    let activeAlertRegions: [RegionPolygon]
    let alertsDict: [String: AlertRegion]
    let lastAlertedRegionName: String?

    private var borderLines: [BorderPolyline] {
        BorderLinesCache.shared.getLines(
            activeAlertRegions: activeAlertRegions,
            activeThreatRegions: activeThreatRegions,
            safeRegions: safeRegions,
            alertsDict: alertsDict
        )
    }

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
        // PASS 2: DEDUPLICATED BORDER STROKES (Red > Yellow > Blue, 0.85px Single Line)
        // =========================================================================

        ForEach(borderLines) { line in
            MapPolyline(coordinates: line.coordinates)
                .stroke(line.color, style: StrokeStyle(lineWidth: thinStrokeWidth, lineCap: .round, lineJoin: .round))
                .mapOverlayLevel(level: .aboveRoads)
        }
    }
}
