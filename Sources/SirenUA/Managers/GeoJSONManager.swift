import Foundation
import MapKit
import OSLog

private let geoLogger = Logger(subsystem: "com.sirenua", category: "GeoJSON")

// MARK: - Models

struct IdentifiableMKPolygon: Identifiable, Equatable {
    let id: String
    let polygon: MKPolygon

    static func == (lhs: IdentifiableMKPolygon, rhs: IdentifiableMKPolygon) -> Bool {
        lhs.id == rhs.id
    }
}

struct RegionPolygon: Identifiable, Equatable {
    let id: String
    let name: String
    let nameUK: String
    let polygons: [[CLLocationCoordinate2D]]
    let mkPolygons: [MKPolygon]
    let identifiablePolygons: [IdentifiableMKPolygon]
    let center: CLLocationCoordinate2D
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double

    static func == (lhs: RegionPolygon, rhs: RegionPolygon) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - GeoJSONManager

@MainActor
final class GeoJSONManager: ObservableObject {

    @Published private(set) var regions: [RegionPolygon] = []
    @Published private(set) var isLoaded = false

    private nonisolated static let fallbackCenter = CLLocationCoordinate2D(latitude: 48.3794, longitude: 31.1656)

    init() {
        Task { await loadGeoJSON() }
    }

    // MARK: - Loading

    private func loadGeoJSON() async {
        geoLogger.info("Loading ukraine_regions.geojson...")

        guard let url = Bundle.main.url(forResource: "ukraine_regions", withExtension: "geojson") else {
            geoLogger.error("ukraine_regions.geojson not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let parsed = try await Task.detached(priority: .userInitiated) {
                try Self.parse(data: data)
            }.value

            regions = parsed
            isLoaded = true
            geoLogger.info("Loaded \(parsed.count) regions from GeoJSON")
        } catch {
            geoLogger.error("GeoJSON load failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Parsing (off main thread)

    private nonisolated static func parse(data: Data) throws -> [RegionPolygon] {
        let decoder = MKGeoJSONDecoder()
        let objects = try decoder.decode(data)

        var result: [RegionPolygon] = []

        for object in objects {
            guard let feature = object as? MKGeoJSONFeature else { continue }

            let (nameEn, nameUk) = extractNames(from: feature)
            let (polygons, mkPolygons) = extractPolygons(from: feature)
            let bounds = computeBounds(from: polygons)
            let center = bounds.map { CLLocationCoordinate2D(latitude: ($0.minLat + $0.maxLat) / 2.0, longitude: ($0.minLon + $0.maxLon) / 2.0) } ?? fallbackCenter

            let identifiable = mkPolygons.enumerated().map { idx, poly in
                IdentifiableMKPolygon(id: "\(nameUk)_\(idx)", polygon: poly)
            }
            let region = RegionPolygon(
                id: nameUk,
                name: nameEn,
                nameUK: nameUk,
                polygons: polygons,
                mkPolygons: mkPolygons,
                identifiablePolygons: identifiable,
                center: center,
                minLat: bounds?.minLat ?? center.latitude,
                maxLat: bounds?.maxLat ?? center.latitude,
                minLon: bounds?.minLon ?? center.longitude,
                maxLon: bounds?.maxLon ?? center.longitude
            )
            result.append(region)
        }

        return result
    }

    private nonisolated static func extractNames(from feature: MKGeoJSONFeature) -> (en: String, uk: String) {
        guard let propertiesData = feature.properties,
              let properties = try? JSONSerialization.jsonObject(with: propertiesData) as? [String: Any]
        else { return ("Unknown", "Unknown") }

        let nameEn = properties["name:en"] as? String ?? properties["name"] as? String ?? "Unknown"
        let nameUk = properties["name:uk"] as? String ?? properties["name"] as? String ?? "Unknown"
        return (nameEn, nameUk)
    }

    private nonisolated static func simplifyCoordinates(_ coords: [CLLocationCoordinate2D], minDistanceSq: Double = 0.0000006) -> [CLLocationCoordinate2D] {
        guard coords.count > 4 else { return coords }
        var result: [CLLocationCoordinate2D] = []
        result.reserveCapacity(coords.count / 3)
        
        var last = coords[0]
        result.append(last)
        
        for i in 1..<(coords.count - 1) {
            let pt = coords[i]
            let dLat = pt.latitude - last.latitude
            let dLon = pt.longitude - last.longitude
            let distSq = dLat * dLat + dLon * dLon
            if distSq >= minDistanceSq {
                result.append(pt)
                last = pt
            }
        }
        result.append(coords[coords.count - 1])
        return result
    }

    private nonisolated static func extractPolygons(from feature: MKGeoJSONFeature) -> ([[CLLocationCoordinate2D]], [MKPolygon]) {
        var coords: [[CLLocationCoordinate2D]] = []
        var mkPolys: [MKPolygon] = []

        for geometry in feature.geometry {
            if let polygon = geometry as? MKPolygon {
                let extracted = extractCoordinates(from: polygon)
                let simplified = simplifyCoordinates(extracted)
                coords.append(simplified)
                if let interior = polygon.interiorPolygons, !interior.isEmpty {
                    mkPolys.append(polygon)
                } else {
                    mkPolys.append(MKPolygon(coordinates: simplified, count: simplified.count))
                }
            } else if let multi = geometry as? MKMultiPolygon {
                let sorted = multi.polygons.sorted { $0.pointCount > $1.pointCount }
                for (idx, polygon) in sorted.enumerated() {
                    let extracted = extractCoordinates(from: polygon)
                    let simplified = simplifyCoordinates(extracted)
                    // Keep main landmasses and sizable islands, filter micro islets that cause heavy stroke clusters
                    if idx == 0 || simplified.count >= 15 {
                        coords.append(simplified)
                        if let interior = polygon.interiorPolygons, !interior.isEmpty {
                            mkPolys.append(polygon)
                        } else {
                            mkPolys.append(MKPolygon(coordinates: simplified, count: simplified.count))
                        }
                    }
                }
            }
        }

        return (coords, mkPolys)
    }

    private nonisolated static func extractCoordinates(from polygon: MKPolygon) -> [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid,
            count: polygon.pointCount
        )
        polygon.getCoordinates(&coordinates, range: NSRange(location: 0, length: polygon.pointCount))
        return coordinates
    }

    private nonisolated static func computeBounds(from polygons: [[CLLocationCoordinate2D]]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        let flat = polygons.flatMap { $0 }
        guard !flat.isEmpty,
              let minLat = flat.map(\.latitude).min(),
              let maxLat = flat.map(\.latitude).max(),
              let minLon = flat.map(\.longitude).min(),
              let maxLon = flat.map(\.longitude).max()
        else { return nil }

        return (minLat, maxLat, minLon, maxLon)
    }

    private nonisolated static func computeCenter(from polygons: [[CLLocationCoordinate2D]]) -> CLLocationCoordinate2D? {
        guard let bounds = computeBounds(from: polygons) else { return nil }
        return CLLocationCoordinate2D(
            latitude:  (bounds.minLat + bounds.maxLat) / 2.0,
            longitude: (bounds.minLon + bounds.maxLon) / 2.0
        )
    }
}
