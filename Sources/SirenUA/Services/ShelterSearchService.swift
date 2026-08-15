import Foundation
import MapKit
import CoreLocation
import OSLog

private let searchLogger = Logger(subsystem: "com.sirenua", category: "ShelterSearchService")

// MARK: - Search Result Model

struct ShelterSearchResult {
    let allFoundShelters: [MKMapItem]
    let closestShelter: MKMapItem?
    let targetRadiusMeters: Double
    let warningMessage: String?
    let errorMessage: String?
}

// MARK: - Shelter Search Service

final class ShelterSearchService {
    static let shared = ShelterSearchService()
    
    private init() {}

    /// Performs shelter search prioritizing user preferences, active transport mode, and distance bounds.
    func searchNearbyShelters(
        userCoordinate: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType,
        walkingRadiusKm: Double,
        drivingRadiusKm: Double,
        serverURL: String
    ) async -> ShelterSearchResult {
        // 1. Determine active search radius based on transport mode
        let configuredKm = transportType == .automobile ? drivingRadiusKm : walkingRadiusKm
        let minRadiusKm = transportType == .automobile ? 1.0 : 0.5
        let maxRadiusKm = transportType == .automobile ? 30.0 : 10.0
        let targetRadiusKm = min(max(configuredKm, minRadiusKm), maxRadiusKm)
        let targetRadiusMeters = targetRadiusKm * 1000.0

        // Extended fallback radius to locate the nearest shelter if none exist within the strict perimeter
        let extendedSearchRadiusMeters = transportType == .automobile
            ? max(targetRadiusMeters, 15_000.0)
            : max(targetRadiusMeters, 4_000.0)

        searchLogger.info("Starting shelter search for mode \(transportType == .automobile ? "automobile" : "walking"). User: (\(userCoordinate.latitude), \(userCoordinate.longitude)), Target radius: \(Int(targetRadiusMeters))m, Extended: \(Int(extendedSearchRadiusMeters))m")

        // 2. Priority 1: Backend ThreatServer API (OSM & official civil defense datasets)
        var apiShelters: [ShelterItem] = []
        do {
            let networkManager = NetworkManager()
            apiShelters = try await networkManager.fetchShelters(
                serverURL: serverURL,
                lat: userCoordinate.latitude,
                lon: userCoordinate.longitude,
                radiusMeters: extendedSearchRadiusMeters
            )
            searchLogger.info("Backend API returned \(apiShelters.count) shelters")
        } catch {
            searchLogger.warning("Backend Shelter API failed, falling back to MKLocalSearch: \(error.localizedDescription)")
        }

        if !apiShelters.isEmpty {
            let userLoc = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
            
            // Re-verify exact Haversine distance and sort
            let sortedWithDistance = apiShelters.map { shelter -> (shelter: ShelterItem, distance: Double) in
                let shelterLoc = CLLocation(latitude: shelter.lat, longitude: shelter.lon)
                let dist = shelterLoc.distance(from: userLoc)
                return (shelter, dist)
            }.sorted { $0.distance < $1.distance }

            let strictlyWithin = sortedWithDistance.filter { $0.distance <= targetRadiusMeters }
            let withinExtended = sortedWithDistance.filter { $0.distance <= extendedSearchRadiusMeters }

            if let closest = strictlyWithin.first {
                let mapItems = strictlyWithin.map { self.createMapItem(from: $0.shelter) }
                let closestMapItem = createMapItem(from: closest.shelter)
                return ShelterSearchResult(
                    allFoundShelters: mapItems,
                    closestShelter: closestMapItem,
                    targetRadiusMeters: targetRadiusMeters,
                    warningMessage: nil,
                    errorMessage: nil
                )
            } else if let closestExtended = withinExtended.first {
                let mapItem = createMapItem(from: closestExtended.shelter)
                let distText = ShelterFormatter.formatDistance(meters: closestExtended.distance)
                let warn = "Найближче укриття знайдено поза межами обраного радіусу (\(distText))"
                return ShelterSearchResult(
                    allFoundShelters: [mapItem],
                    closestShelter: mapItem,
                    targetRadiusMeters: targetRadiusMeters,
                    warningMessage: warn,
                    errorMessage: nil
                )
            }
        }

        // 3. Priority 2: Apple MapKit MKLocalSearch fallback
        searchLogger.info("Executing MKLocalSearch for civil defense shelters...")
        let localSearchItems = await performLocalSearch(
            center: userCoordinate,
            radiusMeters: extendedSearchRadiusMeters
        )

        let userLoc = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let itemsWithDistance = localSearchItems.map { item -> (item: MKMapItem, distance: Double) in
            let itemLoc = CLLocation(
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
            return (item, itemLoc.distance(from: userLoc))
        }.sorted { $0.distance < $1.distance }

        let preferred = itemsWithDistance.filter { $0.distance <= targetRadiusMeters }
        let extended = itemsWithDistance.filter { $0.distance <= extendedSearchRadiusMeters }

        if let closest = preferred.first {
            return ShelterSearchResult(
                allFoundShelters: preferred.map { $0.item },
                closestShelter: closest.item,
                targetRadiusMeters: targetRadiusMeters,
                warningMessage: nil,
                errorMessage: nil
            )
        } else if let closestExtended = extended.first {
            let distText = ShelterFormatter.formatDistance(meters: closestExtended.distance)
            let warn = "Найближче укриття знайдено поза межами обраного радіусу (\(distText))"
            return ShelterSearchResult(
                allFoundShelters: [closestExtended.item],
                closestShelter: closestExtended.item,
                targetRadiusMeters: targetRadiusMeters,
                warningMessage: warn,
                errorMessage: nil
            )
        }

        // 4. No shelters found
        let radiusStr = ShelterFormatter.formatDistance(meters: targetRadiusMeters)
        let modeStr = transportType == .automobile ? "авто" : "пішки"
        let errorMsg = "Поблизу не знайдено укриттів для режиму «\(modeStr)» (у радіусі \(radiusStr)). Спробуйте збільшити радіус у налаштуваннях."
        
        return ShelterSearchResult(
            allFoundShelters: [],
            closestShelter: nil,
            targetRadiusMeters: targetRadiusMeters,
            warningMessage: nil,
            errorMessage: errorMsg
        )
    }

    // MARK: - Helper Methods

    private func createMapItem(from shelter: ShelterItem) -> MKMapItem {
        let placemark = MKPlacemark(coordinate: shelter.coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = shelter.displayName
        return item
    }

    private func performLocalSearch(
        center: CLLocationCoordinate2D,
        radiusMeters: Double
    ) async -> [MKMapItem] {
        let searchRegion = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )

        let queries = [
            "бомбосховище", "укриття цивільного захисту", "найпростіше укриття",
            "бункер", "протирадіаційне укриття", "ПРУ",
            "споруда подвійного призначення", "захисна споруда цивільного захисту",
            "станція метро", "підземний паркінг", "підземне сховище",
            "bomb shelter", "bunker"
        ]

        var rawItems: [MKMapItem] = []

        await withTaskGroup(of: [MKMapItem]?.self) { group in
            for query in queries {
                group.addTask {
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = query
                    request.region = searchRegion
                    let search = MKLocalSearch(request: request)
                    do {
                        let response = try await search.start()
                        return response.mapItems
                    } catch {
                        return nil
                    }
                }
            }

            for await items in group {
                if let items = items {
                    rawItems.append(contentsOf: items)
                }
            }
        }

        // Exclusion list: weather stops, gazebos, rain awnings, beach shades, cafes
        let excludedKeywords = [
            "дощ", "зупинка", "навіс", "альтанка", "павільйон", "тент",
            "палатка", "павіліон", "пляж", "кафе", "ресторан", "маф", "кіоск", "мангал",
            "rain", "bus stop", "gazebo", "awning", "tent", "transit", "stop", "platform"
        ]

        var uniqueItems: [MKMapItem] = []

        for item in rawItems {
            let nameLower = (item.name ?? "").lowercased()

            // Filter out non-defense categories
            if let category = item.pointOfInterestCategory {
                if category == .publicTransport || category == .park || category == .beach ||
                   category == .restaurant || category == .cafe || category == .gasStation ||
                   category == .restroom || category == .nightlife || category == .campground {
                    continue
                }
            }

            let isUndergroundParking = nameLower.contains("паркінг") || nameLower.contains("парковка")
            let isSubway = nameLower.contains("метро") || nameLower.contains("subway")
            
            if !isUndergroundParking && !isSubway {
                let isRainShelter = excludedKeywords.contains { nameLower.contains($0) }
                if isRainShelter { continue }
            }

            // Deduplicate by coordinate proximity (< 25m)
            let coord = item.placemark.coordinate
            let isDuplicate = uniqueItems.contains { existing in
                let extCoord = existing.placemark.coordinate
                let locA = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let locB = CLLocation(latitude: extCoord.latitude, longitude: extCoord.longitude)
                return locA.distance(from: locB) < 25.0
            }

            if !isDuplicate {
                uniqueItems.append(item)
            }
        }

        return uniqueItems
    }
}
