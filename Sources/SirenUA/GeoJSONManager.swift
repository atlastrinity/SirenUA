import Foundation
import MapKit
import OSLog

private let geoLogger = Logger(subsystem: "com.sirenua", category: "GeoJSON")

// MARK: - Models

struct IdentifiableMKPolygon: Identifiable {
    let id = UUID()
    let polygon: MKPolygon
}

struct RegionPolygon: Identifiable {
    let id = UUID()
    let name: String
    let nameUK: String
    let polygons: [[CLLocationCoordinate2D]]
    let mkPolygons: [MKPolygon]
    let identifiablePolygons: [IdentifiableMKPolygon]
    let center: CLLocationCoordinate2D
}

// MARK: - GeoJSONManager

@MainActor
final class GeoJSONManager: ObservableObject {

    @Published private(set) var regions: [RegionPolygon] = []
    @Published private(set) var isLoaded = false

    private static let fallbackCenter = CLLocationCoordinate2D(latitude: 48.3794, longitude: 31.1656)

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
            let center = computeCenter(from: polygons) ?? fallbackCenter

            let identifiable = mkPolygons.map { IdentifiableMKPolygon(polygon: $0) }
            let region = RegionPolygon(
                name: nameEn,
                nameUK: nameUk,
                polygons: polygons,
                mkPolygons: mkPolygons,
                identifiablePolygons: identifiable,
                center: center
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

    private nonisolated static func extractPolygons(from feature: MKGeoJSONFeature) -> ([[CLLocationCoordinate2D]], [MKPolygon]) {
        var coords: [[CLLocationCoordinate2D]] = []
        var mkPolys: [MKPolygon] = []

        for geometry in feature.geometry {
            if let polygon = geometry as? MKPolygon {
                coords.append(extractCoordinates(from: polygon))
                mkPolys.append(polygon)
            } else if let multi = geometry as? MKMultiPolygon {
                for polygon in multi.polygons {
                    coords.append(extractCoordinates(from: polygon))
                    mkPolys.append(polygon)
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

    private nonisolated static func computeCenter(from polygons: [[CLLocationCoordinate2D]]) -> CLLocationCoordinate2D? {
        let flat = polygons.flatMap { $0 }
        guard !flat.isEmpty,
              let minLat = flat.map(\.latitude).min(),
              let maxLat = flat.map(\.latitude).max(),
              let minLon = flat.map(\.longitude).min(),
              let maxLon = flat.map(\.longitude).max()
        else { return nil }

        return CLLocationCoordinate2D(
            latitude:  (minLat + maxLat) / 2.0,
            longitude: (minLon + maxLon) / 2.0
        )
    }
}
