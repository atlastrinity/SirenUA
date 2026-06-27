import Foundation
import MapKit

@available(iOS 17.0, *)
struct RegionPolygon: Identifiable {
    let id = UUID()
    let name: String
    let nameUK: String
    let polygons: [[CLLocationCoordinate2D]]
}

@available(iOS 17.0, *)
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
                    
                    for geometry in feature.geometry {
                        if let polygon = geometry as? MKPolygon {
                            featurePolygons.append(extractCoordinates(from: polygon))
                        } else if let multiPolygon = geometry as? MKMultiPolygon {
                            for polygon in multiPolygon.polygons {
                                featurePolygons.append(extractCoordinates(from: polygon))
                            }
                        }
                    }
                    
                    let region = RegionPolygon(name: nameEn, nameUK: nameUk, polygons: featurePolygons)
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
