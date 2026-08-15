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
    @Published var isShelterPanelVisible = false
    @Published var isNavigating = false
    @Published var isRoutingToShelter = false
    @Published var selectedRegionForDetail: AlertRegion? = nil
    @Published var selectedRegionForHistory: AlertRegion? = nil
    
    private var shelterDismissTask: Task<Void, Never>? = nil

    func showShelterPanel(autoHideAfter seconds: Double = 10.0) {
        shelterDismissTask?.cancel()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            isShelterPanelVisible = true
        }
        shelterDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.45)) {
                    self.isShelterPanelVisible = false
                    if self.selectedTab == 2 {
                        self.selectedTab = 0
                    }
                }
            }
        }
    }

    func hideShelterPanel() {
        shelterDismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.45)) {
            isShelterPanelVisible = false
            if selectedTab == 2 {
                selectedTab = 0
            }
        }
    }
    
    // States for found shelter and routing
    @Published var foundShelter: MKMapItem? = nil
    @Published var selectedShelter: MKMapItem? = nil
    @Published var allFoundShelters: [MKMapItem] = []
    @Published var route: MKRoute? = nil
    @Published var isCalculatingRoute = false
    @Published var routeErrorMessage: String? = nil
    @Published var shelterInfoMessage: String? = nil
    
    // Initial camera focused on active threat region for close-up view
    @Published var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 49.0, longitude: 34.0),
            span: MKCoordinateSpan(latitudeDelta: 2.8, longitudeDelta: 4.2)
        )
    )

    // Dynamic Camera Scale & Distance Tracking for iPhone Map Responsiveness
    @Published var cameraDistance: Double = 600_000.0

    /// Sub-linear scale factor for UI elements (badges, chevrons, icons).
    /// Scales up gracefully when zoomed in, shrinks slightly when zoomed out to prevent map clutter.
    var elementZoomScale: CGFloat {
        let minDist = 3_000.0     // ~3km (zoomed in to city)
        let maxDist = 1_800_000.0 // ~1800km (zoomed out overview)
        let clamped = max(minDist, min(maxDist, cameraDistance))
        
        let minLog = log10(minDist)
        let maxLog = log10(maxDist)
        let curLog = log10(clamped)
        
        let t = (curLog - minLog) / (maxLog - minLog) // 0.0 (zoomed in) ... 1.0 (zoomed out)
        
        // Sub-linear scale curve: 1.30x zoomed in -> 0.82x zoomed out
        return CGFloat(1.30 - (t * 0.48))
    }

    func updateCameraDistance(_ distance: Double) {
        guard distance > 0 else { return }
        // Require at least 15% relative change to prevent rapid map re-renders & flickering
        let ratio = abs(cameraDistance - distance) / cameraDistance
        guard ratio > 0.15 else { return }
        cameraDistance = distance
    }

    private static let fallbackCoordinate = CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)

    func findNearestShelter(
        userLoc: CLLocationCoordinate2D? = nil,
        walkingSearchRadius: Double,
        drivingSearchRadius: Double,
        serverURL: String,
        presentSheet: Bool = false,
        onLocationDenied: (() -> Void)? = nil
    ) {
        guard !isRoutingToShelter else {
            mapVMLogger.debug("Shelter search already in progress — ignoring duplicate request")
            return
        }

        let locManager = LocationManager.shared
        if locManager.isLocationDenied || !locManager.isLocationServicesEnabled {
            onLocationDenied?()
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

        Task {
            // Asynchronously resolve the real live coordinate instead of jumping to a stale/fallback location
            let resolvedCoord: CLLocationCoordinate2D?
            if let userLoc = userLoc {
                resolvedCoord = userLoc
            } else {
                resolvedCoord = await locManager.resolveUserCoordinate(forceFresh: true)
            }

            guard let finalUserLoc = resolvedCoord else {
                await MainActor.run {
                    self.isRoutingToShelter = false
                    if locManager.isLocationDenied || !locManager.isLocationServicesEnabled {
                        onLocationDenied?()
                    } else {
                        self.routeErrorMessage = "Не вдалося визначити вашу точну геопозицію. Будь ласка, перевірте сигнал GPS та спробуйте ще раз."
                    }
                }
                return
            }

            mapVMLogger.info("Shelter search started. User: (\(finalUserLoc.latitude), \(finalUserLoc.longitude)), preferred radius: \(preferredRadiusMeters)m, max search radius: \(maxSearchRadiusMeters)m")

            // 1. Priority 1: Our server API (real OSM data)
            var apiShelters: [ShelterItem] = []
            do {
                let networkManager = NetworkManager()
                apiShelters = try await networkManager.fetchShelters(
                    serverURL: serverURL,
                    lat: finalUserLoc.latitude,
                    lon: finalUserLoc.longitude,
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
                    self.calculateRoute(from: finalUserLoc, to: closestMapItem)

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

            // 2. Priority 2: Fallback to Apple MKLocalSearch (Civil defense bomb shelters, subway stations & underground parkings only)
            mapVMLogger.info("Falling back to MKLocalSearch for civil defense bomb shelters & underground parkings...")
            let searchRegion = MKCoordinateRegion(center: finalUserLoc, latitudinalMeters: maxSearchRadiusMeters, longitudinalMeters: maxSearchRadiusMeters)

            // Strictly target civil defense bomb shelters, subway stations & underground parkings (excluding rain shelters/bus stops)
            let queries = [
                "бомбосховище", "укриття цивільного захисту", "станція метро",
                "підземний паркінг", "протирадіаційне укриття", "підземне сховище",
                "захисна споруда цивільного захисту"
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

            // Exclude rain shelters, bus stops, gazebo awnings, public transport platforms, cafes
            let excludedKeywords = [
                "дощ", "зупинка", "навіс", "альтанка", "павільйон", "тент",
                "палатка", "павіліон", "пляж", "кафе", "ресторан", "маф", "кіоск", "мангал",
                "rain", "bus stop", "gazebo", "awning", "tent", "transit", "stop", "platform"
            ]
            
            var uniqueItems: [MKMapItem] = []
            for item in allItems {
                let nameLower = (item.name ?? "").lowercased()

                // Filter out public transport stops, parks, food establishments and beaches
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

            let userLocation = CLLocation(latitude: finalUserLoc.latitude, longitude: finalUserLoc.longitude)
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
                self.calculateRoute(from: finalUserLoc, to: closestItem)

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
        let shared = UserDefaults(suiteName: "group.com.sirenua.shared")
        let allTracked = shared?.object(forKey: "allRegionsTracked") as? Bool ?? true
        let trackedString = shared?.string(forKey: "trackedRegionsString") ?? ""
        let trackedList = trackedString.components(separatedBy: ";").filter { !$0.isEmpty }
        
        let isRegionFiltered: (String) -> Bool = { name in
            allTracked || trackedList.contains(name)
        }
        
        // Враховуємо ВСІ активні тривоги (ЧЕРВОНІ) та ВСІ активні загрози/прогнози (ЖОВТІ) без винятку!
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
                
                let centerLat = (minLat + maxLat) / 2.0
                let centerLon = (minLon + maxLon) / 2.0
                
                // Забезпечуємо гнучкий дельта-запас для вертикальних екранів iPhone,
                // щоб ВСІ жовті та червоні області влазили повністю без обрізання!
                let rawLatDelta = max((maxLat - minLat) * 1.55, 2.5)
                let rawLonDelta = max((maxLon - minLon) * 1.65, 3.8)
                
                let latDelta = min(rawLatDelta, 18.0)
                let lonDelta = min(rawLonDelta, 28.0)
                
                let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
                )
                if animated {
                    withAnimation(.easeInOut(duration: 1.2)) {
                        self.cameraPosition = .region(region)
                    }
                } else {
                    self.cameraPosition = region.toCameraPosition()
                }
                return
            }
        }
        
        // Масштаб за замовчуванням (впевнено влазить вся Україна з полями)
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.3794, longitude: 31.1656),
            span: MKCoordinateSpan(latitudeDelta: 9.5, longitudeDelta: 16.5)
        )
        if animated {
            withAnimation(.easeInOut(duration: 1.5)) {
                self.cameraPosition = .region(defaultRegion)
            }
        } else {
            self.cameraPosition = .region(defaultRegion)
        }
    }

    func focusOnSingleRegion(regionName: String, geoManager: GeoJSONManager, alerts: [AlertRegion]) {
        if let alertReg = alerts.first(where: { $0.name == regionName }) {
            selectedRegionForDetail = alertReg
        }
        
        if let geoRegion = geoManager.regions.first(where: { $0.nameUK == regionName }),
           let polygon = geoRegion.polygons.first, !polygon.isEmpty {
            let lats = polygon.map { $0.latitude }
            let lons = polygon.map { $0.longitude }
            if let minLat = lats.min(), let maxLat = lats.max(),
               let minLon = lons.min(), let maxLon = lons.max() {
                let center = CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2.0,
                    longitude: (minLon + maxLon) / 2.0
                )
                let span = MKCoordinateSpan(
                    latitudeDelta: max((maxLat - minLat) * 1.5, 0.8),
                    longitudeDelta: max((maxLon - minLon) * 1.5, 1.2)
                )
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
                }
            }
        } else if let alertReg = alerts.first(where: { $0.name == regionName }) {
            let region = MKCoordinateRegion(
                center: alertReg.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 1.2, longitudeDelta: 1.8)
            )
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.cameraPosition = .region(region)
            }
        }
    }
}

private extension MKCoordinateRegion {
    func toCameraPosition() -> MapCameraPosition {
        .region(self)
    }
}
