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
        districts: [DistrictPolygon],
        alertsDict: [String: AlertRegion]
    ) -> [BorderPolyline] {
        let key = makeFootprint(
            activeAlertRegions: activeAlertRegions,
            activeThreatRegions: activeThreatRegions,
            safeRegions: safeRegions,
            districtsCount: districts.count,
            alertsDict: alertsDict
        )
        if key == cachedKey && !cachedLines.isEmpty {
            return cachedLines
        }

        let lines = computeLines(
            activeAlertRegions: activeAlertRegions,
            activeThreatRegions: activeThreatRegions,
            safeRegions: safeRegions,
            districts: districts,
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
        districtsCount: Int,
        alertsDict: [String: AlertRegion]
    ) -> String {
        let a = activeAlertRegions.map { r in
            let dCount = alertsDict[r.nameUK]?.activeDistricts.count ?? 0
            return "\(r.nameUK)_\(dCount)"
        }.joined(separator: ",")
        let t = activeThreatRegions.map { "\($0.nameUK)_\(alertsDict[$0.nameUK]?.threatLevel ?? "")" }.joined(separator: ",")
        return "\(a)|\(t)|\(safeRegions.count)|\(districtsCount)"
    }

    private func computeLines(
        activeAlertRegions: [RegionPolygon],
        activeThreatRegions: [RegionPolygon],
        safeRegions: [RegionPolygon],
        districts: [DistrictPolygon],
        alertsDict: [String: AlertRegion]
    ) -> [BorderPolyline] {
        var result: [BorderPolyline] = []
        result.reserveCapacity(180)

        // 1. Internal District Borders (Subtle cyan line between districts)
        if !districts.isEmpty {
            let districtBorderColor = Color.cyan.opacity(0.35)
            for (dIdx, district) in districts.enumerated() {
                for (pIdx, polyCoords) in district.polygons.enumerated() {
                    guard polyCoords.count >= 2 else { continue }
                    result.append(BorderPolyline(id: "dist_\(dIdx)_\(pIdx)", coordinates: polyCoords, color: districtBorderColor))
                }
            }
        }

        // 2. Priority 1: Active Alert Regions (Vivid Red)
        for (rIdx, region) in activeAlertRegions.enumerated() {
            let color = Color.red.opacity(0.95)
            for (pIdx, polyCoords) in region.polygons.enumerated() {
                guard polyCoords.count >= 2 else { continue }
                result.append(BorderPolyline(id: "red_\(rIdx)_\(pIdx)", coordinates: polyCoords, color: color))
            }
        }

        // 3. Priority 2: Active Threat Regions (Yellow / Orange)
        for (rIdx, region) in activeThreatRegions.enumerated() {
            let threatColor = alertsDict[region.nameUK]?.color ?? .yellow
            let color = threatColor.opacity(0.95)
            for (pIdx, polyCoords) in region.polygons.enumerated() {
                guard polyCoords.count >= 2 else { continue }
                result.append(BorderPolyline(id: "yellow_\(rIdx)_\(pIdx)", coordinates: polyCoords, color: color))
            }
        }

        // 4. Priority 3: Safe Outer Oblast Borders (Cyan / Blue)
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
    var districts: [DistrictPolygon] = []
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
            districts: districts,
            alertsDict: alertsDict
        )
    }

    var body: some MapContent {
        let thinStrokeWidth: CGFloat = 0.85
        let districtStrokeWidth: CGFloat = 0.50

        // =========================================================================
        // PASS 1: GRANULAR DISTRICT / REGION FILLS
        // =========================================================================

        if !districts.isEmpty {
            // Render 136 Granular Districts
            ForEach(districts) { district in
                let alert = alertsDict[district.parentRegion]
                let isDistrictAlarm = alert?.isDistrictActive(district.nameUK) ?? false
                let isParentThreat = (alert?.threatLevel != nil || !(alert?.activeThreats.isEmpty ?? true))
                
                let fillColor: Color = isDistrictAlarm
                    ? (district.parentRegion == lastAlertedRegionName ? Color(red: 0.96, green: 0.11, blue: 0.16).opacity(0.68) : Color(red: 0.91, green: 0.13, blue: 0.19).opacity(0.58))
                    : (isParentThreat ? (alert?.color ?? .yellow).opacity(0.60) : Color(red: 0.04, green: 0.14, blue: 0.38).opacity(0.32))

                ForEach(district.identifiablePolygons) { item in
                    MapPolygon(item.polygon)
                        .foregroundStyle(fillColor)
                        .mapOverlayLevel(level: .aboveRoads)
                }
            }
        } else {
            // Fallback: 26 Oblast Fills
            ForEach(safeRegions) { region in
                ForEach(region.identifiablePolygons) { item in
                    MapPolygon(item.polygon)
                        .foregroundStyle(Color(red: 0.04, green: 0.14, blue: 0.38).opacity(0.32))
                        .mapOverlayLevel(level: .aboveRoads)
                }
            }

            ForEach(activeThreatRegions) { region in
                let threatColor = alertsDict[region.nameUK]?.color ?? .yellow
                let fillColor: Color = threatColor.opacity(0.62)
                ForEach(region.identifiablePolygons) { item in
                    MapPolygon(item.polygon)
                        .foregroundStyle(fillColor)
                        .mapOverlayLevel(level: .aboveRoads)
                }
            }

            ForEach(activeAlertRegions) { region in
                let isLastAlerted = region.nameUK == lastAlertedRegionName
                let redFill = isLastAlerted ? Color(red: 0.96, green: 0.11, blue: 0.16).opacity(0.68) : Color(red: 0.91, green: 0.13, blue: 0.19).opacity(0.58)
                ForEach(region.identifiablePolygons) { item in
                    MapPolygon(item.polygon)
                        .foregroundStyle(redFill)
                        .mapOverlayLevel(level: .aboveRoads)
                }
            }
        }

        // =========================================================================
        // PASS 2: DEDUPLICATED BORDER STROKES (Districts & Oblasts)
        // =========================================================================

        ForEach(borderLines) { line in
            let width = line.id.hasPrefix("dist_") ? districtStrokeWidth : thinStrokeWidth
            MapPolyline(coordinates: line.coordinates)
                .stroke(line.color, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                .mapOverlayLevel(level: .aboveRoads)
        }
    }
}
