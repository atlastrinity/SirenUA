import Foundation
import MapKit

@available(iOS 16.0, *)
struct IdentifiableMKPolygon: Identifiable {
    let id = UUID()
    let polygon: MKPolygon
}

@available(iOS 16.0, *)
struct RegionPolygon: Identifiable {
    let id = UUID()
    let name: String
    let nameUK: String
    let polygons: [[CLLocationCoordinate2D]]
    let mkPolygons: [MKPolygon]  // Зберігаємо оригінальні MKPolygon для надійного рендерингу
    let identifiablePolygons: [IdentifiableMKPolygon]
    let center: CLLocationCoordinate2D
}

@available(iOS 16.0, *)
class GeoJSONManager: ObservableObject {
    @Published var regions: [RegionPolygon] = []
    
    init() {
        loadGeoJSON()
    }
    
    private func loadGeoJSON() {
        guard let url = Bundle.main.url(forResource: "ukraine_regions", withExtension: "geojson") else {
            print("Error: ukraine_regions.geojson not found in bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            // MapKit provides a native GeoJSON decoder
            let decoder = MKGeoJSONDecoder()
            let objects = try decoder.decode(data)
            
            var parsedRegions: [RegionPolygon] = []
            
            for object in objects {
                if let feature = object as? MKGeoJSONFeature {
                    // Extract properties
                    var nameEn = "Unknown"
                    var nameUk = "Unknown"
                    
                    if let propertiesData = feature.properties {
                        if let properties = try? JSONSerialization.jsonObject(with: propertiesData) as? [String: Any] {
                            nameEn = properties["name:en"] as? String ?? properties["name"] as? String ?? "Unknown"
                            nameUk = properties["name:uk"] as? String ?? properties["name"] as? String ?? "Unknown"
                        }
                    }
                    
                    // Extract geometry (can be Polygon or MultiPolygon)
                    var featurePolygons: [[CLLocationCoordinate2D]] = []
                    var featureMKPolygons: [MKPolygon] = []
                    
                    for geometry in feature.geometry {
                        if let polygon = geometry as? MKPolygon {
                            featurePolygons.append(extractCoordinates(from: polygon))
                            featureMKPolygons.append(polygon)
                        } else if let multiPolygon = geometry as? MKMultiPolygon {
                            for polygon in multiPolygon.polygons {
                                featurePolygons.append(extractCoordinates(from: polygon))
                                featureMKPolygons.append(polygon)
                            }
                        }
                    }
                    // Розраховуємо центр для розміщення маркера
                    var centerCoord = CLLocationCoordinate2D(latitude: 48.3794, longitude: 31.1656)
                    let flatCoords = featurePolygons.flatMap { $0 }
                    if !flatCoords.isEmpty {
                        let lats = flatCoords.map { $0.latitude }
                        let lons = flatCoords.map { $0.longitude }
                        if let minLat = lats.min(), let maxLat = lats.max(),
                           let minLon = lons.min(), let maxLon = lons.max() {
                            centerCoord = CLLocationCoordinate2D(
                                latitude: (minLat + maxLat) / 2.0,
                                longitude: (minLon + maxLon) / 2.0
                            )
                        }
                    }
                    
                    let identifiablePolygons = featureMKPolygons.map { IdentifiableMKPolygon(polygon: $0) }
                    let region = RegionPolygon(name: nameEn, nameUK: nameUk, polygons: featurePolygons, mkPolygons: featureMKPolygons, identifiablePolygons: identifiablePolygons, center: centerCoord)
                    parsedRegions.append(region)
                }
            }
            
            DispatchQueue.main.async {
                self.regions = parsedRegions
            }
            
        } catch {
            print("Error parsing GeoJSON: \(error)")
        }
    }
    
    private func extractCoordinates(from polygon: MKPolygon) -> [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polygon.pointCount)
        polygon.getCoordinates(&coordinates, range: NSRange(location: 0, length: polygon.pointCount))
        return coordinates
    }
}
