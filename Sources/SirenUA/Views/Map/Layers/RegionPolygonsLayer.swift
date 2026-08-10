import SwiftUI
import MapKit

struct BorderPolyline: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}

struct RegionPolygonsLayer: MapContent {
    let safeRegions: [RegionPolygon]
    let activeThreatRegions: [RegionPolygon]
    let activeAlertRegions: [RegionPolygon]
    let alertsDict: [String: AlertRegion]
    let lastAlertedRegionName: String?

    private func segmentKey(_ c1: CLLocationCoordinate2D, _ c2: CLLocationCoordinate2D) -> String {
        let latSum = Int(round((c1.latitude + c2.latitude) * 500))
        let lonSum = Int(round((c1.longitude + c2.longitude) * 500))
        return "\(latSum)_\(lonSum)"
    }

    private var deduplicatedBorderLines: [BorderPolyline] {
        var result: [BorderPolyline] = []
        var seenSegments = Set<String>()
        var lineCounter = 0

        // Priority 1 (Highest): Active Alert Regions (Vivid Red)
        for (rIdx, region) in activeAlertRegions.enumerated() {
            let color = Color.red.opacity(0.95)
            for (pIdx, polyCoords) in region.polygons.enumerated() {
                guard polyCoords.count >= 2 else { continue }
                var currentChunk: [CLLocationCoordinate2D] = []

                for i in 0..<(polyCoords.count - 1) {
                    let c1 = polyCoords[i]
                    let c2 = polyCoords[i + 1]
                    let key = segmentKey(c1, c2)

                    if !seenSegments.contains(key) {
                        seenSegments.insert(key)
                        if currentChunk.isEmpty {
                            currentChunk.append(c1)
                        }
                        currentChunk.append(c2)
                    } else {
                        if currentChunk.count >= 2 {
                            lineCounter += 1
                            result.append(BorderPolyline(id: "red_\(rIdx)_\(pIdx)_\(lineCounter)", coordinates: currentChunk, color: color))
                            currentChunk = []
                        }
                    }
                }

                if currentChunk.count >= 2 {
                    lineCounter += 1
                    result.append(BorderPolyline(id: "red_\(rIdx)_\(pIdx)_\(lineCounter)", coordinates: currentChunk, color: color))
                }
            }
        }

        // Priority 2 (Medium): Active Threat Regions (Yellow / Orange - overwrites Blue)
        for (rIdx, region) in activeThreatRegions.enumerated() {
            let threatColor = alertsDict[region.nameUK]?.color ?? .yellow
            let color = threatColor.opacity(0.95)

            for (pIdx, polyCoords) in region.polygons.enumerated() {
                guard polyCoords.count >= 2 else { continue }
                var currentChunk: [CLLocationCoordinate2D] = []

                for i in 0..<(polyCoords.count - 1) {
                    let c1 = polyCoords[i]
                    let c2 = polyCoords[i + 1]
                    let key = segmentKey(c1, c2)

                    if !seenSegments.contains(key) {
                        seenSegments.insert(key)
                        if currentChunk.isEmpty {
                            currentChunk.append(c1)
                        }
                        currentChunk.append(c2)
                    } else {
                        if currentChunk.count >= 2 {
                            lineCounter += 1
                            result.append(BorderPolyline(id: "yellow_\(rIdx)_\(pIdx)_\(lineCounter)", coordinates: currentChunk, color: color))
                            currentChunk = []
                        }
                    }
                }

                if currentChunk.count >= 2 {
                    lineCounter += 1
                    result.append(BorderPolyline(id: "yellow_\(rIdx)_\(pIdx)_\(lineCounter)", coordinates: currentChunk, color: color))
                }
            }
        }

        // Priority 3 (Lowest): Safe Regions (Cyan / Blue)
        let cyanColor = Color.cyan.opacity(0.85)
        for (rIdx, region) in safeRegions.enumerated() {
            for (pIdx, polyCoords) in region.polygons.enumerated() {
                guard polyCoords.count >= 2 else { continue }
                var currentChunk: [CLLocationCoordinate2D] = []

                for i in 0..<(polyCoords.count - 1) {
                    let c1 = polyCoords[i]
                    let c2 = polyCoords[i + 1]
                    let key = segmentKey(c1, c2)

                    if !seenSegments.contains(key) {
                        seenSegments.insert(key)
                        if currentChunk.isEmpty {
                            currentChunk.append(c1)
                        }
                        currentChunk.append(c2)
                    } else {
                        if currentChunk.count >= 2 {
                            lineCounter += 1
                            result.append(BorderPolyline(id: "cyan_\(rIdx)_\(pIdx)_\(lineCounter)", coordinates: currentChunk, color: cyanColor))
                            currentChunk = []
                        }
                    }
                }

                if currentChunk.count >= 2 {
                    lineCounter += 1
                    result.append(BorderPolyline(id: "cyan_\(rIdx)_\(pIdx)_\(lineCounter)", coordinates: currentChunk, color: cyanColor))
                }
            }
        }

        return result
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

        ForEach(deduplicatedBorderLines) { line in
            MapPolyline(coordinates: line.coordinates)
                .stroke(line.color, style: StrokeStyle(lineWidth: thinStrokeWidth, lineCap: .round, lineJoin: .round))
                .mapOverlayLevel(level: .aboveRoads)
        }
    }
}
