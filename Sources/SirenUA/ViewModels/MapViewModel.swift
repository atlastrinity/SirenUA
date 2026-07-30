import Foundation
import MapKit
import SwiftUI
import OSLog

private let mapVMLogger = Logger(subsystem: "com.sirenua", category: "MapViewModel")

@MainActor
final class MapViewModel: ObservableObject {
    @Published var selectedTab = 0
    @Published var transportType: MKDirectionsTransportType = .walking
    @Published var activeSheet: ActiveSheet? = nil
    @Published var showHistory = false
    @Published var showActiveAlerts = false
    @Published var isNavigating = false
    @Published var isRoutingToShelter = false
    @Published var selectedRegionForDetail: AlertRegion? = nil
    
    // States for found shelter and routing
    @Published var foundShelter: MKMapItem? = nil
    @Published var selectedShelter: MKMapItem? = nil
    @Published var allFoundShelters: [MKMapItem] = []
    @Published var route: MKRoute? = nil
    @Published var isCalculatingRoute = false
    @Published var routeErrorMessage: String? = nil
    @Published var shelterInfoMessage: String? = nil
    
    // Initial camera focused on Kyiv
    @Published var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234),
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    )

    private static let fallbackCoordinate = CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)

    func findNearestShelter(
        userLoc: CLLocationCoordinate2D,
        walkingSearchRadius: Double,
        drivingSearchRadius: Double,
        serverURL: String,
        presentSheet: Bool = false
    ) {
        guard !isRoutingToShelter else {
            mapVMLogger.debug("Shelter search already in progress — ignoring duplicate request")
            return
        }
        isRoutingToShelter = true

        withAnimation {
            shelterInfoMessage = nil
            routeErrorMessage = nil
        }

        let currentRadius = transportType == .automobile ? drivingSearchRadius : walkingSearchRadius
        let preferredRadiusMeters = max(currentRadius, 0.5) * 1000
        let maxSearchRadiusMeters = transportType == .automobile ? max(preferredRadiusMeters, 20000) : max(preferredRadiusMeters, 5000)
        
        mapVMLogger.info("Shelter search started. User: (\(userLoc.latitude), \(userLoc.longitude)), preferred radius: \(preferredRadiusMeters)m, max search radius: \(maxSearchRadiusMeters)m")

        Task {
            // 1. Priority 1: Our server API (real OSM data)
            var apiShelters: [ShelterItem] = []
            do {
                let networkManager = NetworkManager()
                apiShelters = try await networkManager.fetchShelters(
                    serverURL: serverURL,
                    lat: userLoc.latitude,
                    lon: userLoc.longitude,
                    radiusMeters: maxSearchRadiusMeters
                )
                mapVMLogger.info("API returned \(apiShelters.count) shelters")
            } catch {
                mapVMLogger.warning("Shelter API failed, falling back to MKLocalSearch: \(error.localizedDescription)")
            }

            if !apiShelters.isEmpty {
                let preferredShelters = apiShelters.filter { $0.distance_m <= preferredRadiusMeters }
                
                let displayedShelters: [ShelterItem]
                let closestShelter: ShelterItem
                let warningMsg: String?
                
                if !preferredShelters.isEmpty {
                    displayedShelters = preferredShelters
                    closestShelter = preferredShelters[0]
                    warningMsg = nil
                } else {
                    displayedShelters = [apiShelters[0]]
                    closestShelter = apiShelters[0]
                    warningMsg = "Найближче укриття знайдено поза межами обраного радіусу (\(apiShelters[0].distanceText))"
                }

                let mapItems = displayedShelters.map { shelter -> MKMapItem in
                    let placemark = MKPlacemark(coordinate: shelter.coordinate)
                    let item = MKMapItem(placemark: placemark)
                    item.name = shelter.name ?? shelter.typeDescription
                    if let addr = shelter.address {
                        item.name = "\(item.name ?? "Укриття") — \(addr)"
                    }
                    return item
                }
                
                let closestMapItem = MKMapItem(placemark: MKPlacemark(coordinate: closestShelter.coordinate))
                closestMapItem.name = closestShelter.name ?? closestShelter.typeDescription
                if let addr = closestShelter.address {
                    closestMapItem.name = "\(closestMapItem.name ?? "Укриття") — \(addr)"
                }

                await MainActor.run {
                    self.isRoutingToShelter = false
                    self.allFoundShelters = mapItems
                    self.shelterInfoMessage = warningMsg

                    self.foundShelter = closestMapItem
                    if presentSheet {
                        self.selectedShelter = closestMapItem
                    }
                    self.route = nil
                    self.routeErrorMessage = nil
                    self.isCalculatingRoute = false
                    self.calculateRoute(from: userLoc, to: closestMapItem)

                    withAnimation(.easeInOut(duration: 1.0)) {
                        self.cameraPosition = .region(
                            MKCoordinateRegion(
                                center: closestMapItem.placemark.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        )
                    }
                }
                return
            }

            // 2. Priority 2: Fallback to Apple MKLocalSearch (Civil defense bomb shelters & subway stations only)
            mapVMLogger.info("Falling back to MKLocalSearch for civil defense bomb shelters...")
            let searchRegion = MKCoordinateRegion(center: userLoc, latitudinalMeters: maxSearchRadiusMeters, longitudinalMeters: maxSearchRadiusMeters)

            // Strictly target civil defense bomb shelters, subway stations & underground parkings (excluding rain shelters/bus stops)
            let queries = [
                "бомбосховище", "укриття цивільного захисту", "станція метро",
                "підземний паркінг", "протирадіаційне укриття", "підземне укриття"
            ]

            var allItems: [MKMapItem] = []

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
                        allItems.append(contentsOf: items)
                    }
                }
            }

            // Exclude rain shelters, bus stops, gazebo awnings
            let excludedKeywords = ["дощ", "зупинка", "навіс", "альтанка", "павільйон", "rain", "bus stop", "gazebo", "awning"]
            
            var uniqueItems: [MKMapItem] = []
            for item in allItems {
                let nameLower = (item.name ?? "").lowercased()
                let isRainShelter = excludedKeywords.contains { nameLower.contains($0) }
                if isRainShelter { continue }

                let coord = item.placemark.coordinate
                let isDuplicate = uniqueItems.contains { existing in
                    let extCoord = existing.placemark.coordinate
                    let latDiff = abs(extCoord.latitude - coord.latitude)
                    let lonDiff = abs(extCoord.longitude - coord.longitude)
                    return latDiff < 0.00005 && lonDiff < 0.00005
                }
                if !isDuplicate {
                    uniqueItems.append(item)
                }
            }

            let userLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
            let itemsWithDistance = uniqueItems.map { item -> (item: MKMapItem, distance: Double) in
                let itemLocation = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                let distance = itemLocation.distance(from: userLocation)
                return (item, distance)
            }

            let preferredItems = itemsWithDistance.filter { $0.distance <= preferredRadiusMeters }

            let displayedItems: [MKMapItem]
            let closestItem: MKMapItem?
            let warningMsg: String?

            if !preferredItems.isEmpty {
                displayedItems = preferredItems.map { $0.item }
                closestItem = preferredItems.min(by: { a, b in a.distance < b.distance })?.item
                warningMsg = nil
            } else if let absoluteClosest = itemsWithDistance.min(by: { a, b in a.distance < b.distance }) {
                displayedItems = [absoluteClosest.item]
                closestItem = absoluteClosest.item
                let distText = absoluteClosest.distance < 1000
                    ? "\(Int(absoluteClosest.distance)) м"
                    : String(format: "%.1f км", absoluteClosest.distance / 1000)
                warningMsg = "Найближче укриття знайдено поза межами обраного радіусу (\(distText))"
            } else {
                displayedItems = []
                closestItem = nil
                warningMsg = nil
            }

            await MainActor.run {
                self.isRoutingToShelter = false
                
                guard let closestItem else {
                    self.allFoundShelters = []
                    self.foundShelter = nil
                    self.selectedShelter = nil
                    self.route = nil
                    self.routeErrorMessage = "Не знайдено жодного укриття. Спробуйте збільшити радіус у налаштуваннях."
                    self.isCalculatingRoute = false
                    return
                }

                self.allFoundShelters = displayedItems
                self.foundShelter = closestItem
                if presentSheet {
                    self.selectedShelter = closestItem
                }
                self.route = nil
                self.routeErrorMessage = nil
                self.shelterInfoMessage = warningMsg
                self.isCalculatingRoute = false
                self.calculateRoute(from: userLoc, to: closestItem)

                withAnimation(.easeInOut(duration: 1.0)) {
                    self.cameraPosition = .region(
                        MKCoordinateRegion(
                            center: closestItem.placemark.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                }
            }
        }
    }

    func calculateRoute(from sourceCoordinate: CLLocationCoordinate2D, to destination: MKMapItem) {
        guard !isCalculatingRoute else { return }
        routeErrorMessage = nil
        isCalculatingRoute = true
        
        let request = MKDirections.Request()
        let sourcePlacemark = MKPlacemark(coordinate: sourceCoordinate)
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = destination
        request.transportType = transportType

        Task {
            let directions = MKDirections(request: request)
            do {
                let response = try await directions.calculate()
                await MainActor.run {
                    self.route = response.routes.first
                    self.isCalculatingRoute = false
                    withAnimation {
                        if let rect = self.route?.polyline.boundingMapRect {
                            self.cameraPosition = .rect(rect.insetBy(dx: -500, dy: -500))
                        }
                    }
                }
            } catch {
                if request.transportType == .walking {
                    let fallbackRequest = MKDirections.Request()
                    fallbackRequest.source = request.source
                    fallbackRequest.destination = destination
                    fallbackRequest.transportType = .automobile
                    
                    if let fallbackResponse = try? await MKDirections(request: fallbackRequest).calculate() {
                        await MainActor.run {
                            self.transportType = .automobile
                            self.route = fallbackResponse.routes.first
                            self.isCalculatingRoute = false
                            withAnimation {
                                if let rect = self.route?.polyline.boundingMapRect {
                                    self.cameraPosition = .rect(rect.insetBy(dx: -500, dy: -500))
                                }
                            }
                        }
                        return
                    }
                }
                
                await MainActor.run {
                    self.isCalculatingRoute = false
                    self.routeErrorMessage = "Маршрут недоступний"
                }
            }
        }
    }
    
    func centerMapOnAlerts(alerts: [AlertRegion], isPremium: Bool, lastAlertedRegionName: String?, regions: [RegionPolygon], animated: Bool = true) {
        let allTracked = UserDefaults.standard.object(forKey: "allRegionsTracked") as? Bool ?? true
        let trackedString = UserDefaults.standard.object(forKey: "trackedRegionsString") as? String ?? ""
        let trackedList = trackedString.components(separatedBy: ";").filter { !$0.isEmpty }
        
        let isRegionFiltered: (String) -> Bool = { name in
            allTracked || trackedList.contains(name)
        }
        
        let activeTrackedAlerts = alerts.filter { $0.isActive && isRegionFiltered($0.name) }
        let activeTrackedThreats = isPremium ? alerts.filter { !($0.isActive) && $0.threatLevel != nil && isRegionFiltered($0.name) } : []
        let relevantAlerts = activeTrackedAlerts + activeTrackedThreats
        let activeNames = Set(relevantAlerts.map { $0.name })
        let activeRegions = regions.filter { activeNames.contains($0.nameUK) }
        
        var allCoordinates: [CLLocationCoordinate2D] = []
        for region in activeRegions {
            for polygon in region.polygons {
                allCoordinates.append(contentsOf: polygon)
            }
        }
        
        if allCoordinates.isEmpty {
            allCoordinates = relevantAlerts.map { $0.coordinate }
        }
        
        if allCoordinates.isEmpty {
            if !allTracked && !trackedList.isEmpty {
                let monitoredRegions = regions.filter { trackedList.contains($0.nameUK) }
                for region in monitoredRegions {
                    for polygon in region.polygons {
                        allCoordinates.append(contentsOf: polygon)
                    }
                }
            }
        }
        
        if !allCoordinates.isEmpty {
            let lats = allCoordinates.map { $0.latitude }
            let lons = allCoordinates.map { $0.longitude }
            if let minLat = lats.min(), let maxLat = lats.max(),
               let minLon = lons.min(), let maxLon = lons.max() {
                
                let centerLat: Double
                let centerLon: Double
                let latDelta: Double
                let lonDelta: Double
                
                if !relevantAlerts.isEmpty {
                    centerLat = relevantAlerts.map { $0.coordinate.latitude }.reduce(0, +) / Double(relevantAlerts.count)
                    centerLon = relevantAlerts.map { $0.coordinate.longitude }.reduce(0, +) / Double(relevantAlerts.count)
                    
                    let maxLatDist = max(abs(maxLat - centerLat), abs(centerLat - minLat))
                    let maxLonDist = max(abs(maxLon - centerLon), abs(centerLon - minLon))
                    
                    latDelta = max(maxLatDist * 2, 1.0) * 1.3
                    lonDelta = max(maxLonDist * 2, 1.5) * 1.3
                } else {
                    centerLat = (minLat + maxLat) / 2.0
                    centerLon = (minLon + maxLon) / 2.0
                    
                    latDelta = max(maxLat - minLat, 1.0) * 1.3
                    lonDelta = max(maxLon - minLon, 1.5) * 1.3
                }
                
                let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    span: MKCoordinateSpan(
                        latitudeDelta: min(latDelta, 8.0),
                        longitudeDelta: min(lonDelta, 13.0)
                    )
                )
                if animated {
                    withAnimation(.easeInOut(duration: 2.0)) {
                        self.cameraPosition = .region(region)
                    }
                } else {
                    self.cameraPosition = region.toCameraPosition()
                }
                return
            }
        }
        
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.3794, longitude: 31.1656),
            span: MKCoordinateSpan(latitudeDelta: 7.5, longitudeDelta: 12.5)
        )
        if animated {
            withAnimation(.easeInOut(duration: 2.0)) {
                self.cameraPosition = .region(defaultRegion)
            }
        } else {
            self.cameraPosition = .region(defaultRegion)
        }
    }
}

private extension MKCoordinateRegion {
    func toCameraPosition() -> MapCameraPosition {
        .region(self)
    }
}
