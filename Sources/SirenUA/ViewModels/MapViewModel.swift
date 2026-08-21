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
    
    // MARK: - States for found shelter and routing
    @Published var foundShelter: MKMapItem? = nil
    @Published var selectedShelter: MKMapItem? = nil
    @Published var allFoundShelters: [MKMapItem] = []
    @Published var route: MKRoute? = nil
    @Published var isCalculatingRoute = false
    @Published var routeErrorMessage: String? = nil
    @Published var shelterInfoMessage: String? = nil
    
    // Initial camera focused on Ukraine combat theater overview
    @Published var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.6, longitude: 31.8),
            span: MKCoordinateSpan(latitudeDelta: 5.2, longitudeDelta: 7.8)
        )
    )

    // Dynamic Camera Scale & Distance Tracking for iPhone Map Responsiveness
    @Published var cameraDistance: Double = 600_000.0
    @Published var cameraHeading: Double = 0.0

    /// Sub-linear scale factor for UI elements (badges, tablets, chevrons, icons).
    /// Scales up gracefully by +150% when zooming in from standard overview baseline (1.00 -> 2.50)
    /// to make region names, threat types, origin launch hubs, and arrows crystal clear and readable.
    var elementZoomScale: CGFloat {
        let overviewDist = 1_000_000.0 // ~1000km (standard full Ukraine overview baseline = 1.00)
        let closeDist = 15_000.0       // ~15km (zoomed in to city/district level = 2.50, i.e. +150%)
        let maxOverviewDist = 2_500_000.0 // ~2500km (extreme zoomed out overview)
        
        let clampedDist = max(closeDist, min(maxOverviewDist, cameraDistance))
        
        let rawScale: CGFloat
        if clampedDist <= overviewDist {
            // Zooming in from overview (1000km) to city level (15km):
            // Smoothly increase scale from 1.00 up to 2.50 (+150% magnification)
            let minLog = log10(closeDist)
            let maxLog = log10(overviewDist)
            let curLog = log10(clampedDist)
            let t = (maxLog - curLog) / (maxLog - minLog) // 0.0 (overview) -> 1.0 (zoomed in)
            rawScale = CGFloat(1.00 + (t * 1.50))
        } else {
            // Zooming out further than standard overview (1000km -> 2500km):
            // Gentle sub-linear compacting (1.00 -> 0.90) to keep 25 regions clean
            let minLog = log10(overviewDist)
            let maxLog = log10(maxOverviewDist)
            let curLog = log10(clampedDist)
            let outT = (curLog - minLog) / (maxLog - minLog) // 0.0 (overview) -> 1.0 (extreme zoom out)
            rawScale = CGFloat(1.00 - (outT * 0.10))
        }
        // Quantize scale to 0.05 increments to eliminate sub-pixel jitter & excess layout passes
        return (rawScale * 20.0).rounded() / 20.0
    }

    func updateCamera(distance: Double, heading: Double) {
        guard distance > 0 else { return }
        let distRatio = abs(cameraDistance - distance) / cameraDistance
        let headingDiff = abs(cameraHeading - heading)
        if distRatio > 0.035 {
            cameraDistance = distance
        }
        if headingDiff > 1.5 {
            cameraHeading = heading
        }
    }

    func updateCameraDistance(_ distance: Double) {
        guard distance > 0 else { return }
        let ratio = abs(cameraDistance - distance) / cameraDistance
        guard ratio > 0.035 else { return }
        cameraDistance = distance
    }

    // MARK: - Map Centering on Alerts & Threats
    
    func centerMapOnAlerts(alerts: [AlertRegion], isPremium: Bool, lastAlertedRegionName: String?, regions: [RegionPolygon], animated: Bool = true) {
        let shared = UserDefaults(suiteName: "group.com.sirenua.shared")
        let allTracked = shared?.object(forKey: "allRegionsTracked") as? Bool ?? true
        let trackedString = shared?.string(forKey: "trackedRegionsString") ?? ""
        let trackedList = trackedString.components(separatedBy: ";").filter { !$0.isEmpty }
        
        let isRegionFiltered: (String) -> Bool = { name in
            allTracked || trackedList.contains(name)
        }
        
        // Враховуємо ВСІ активні тривоги (ЧЕРВОНІ) та ВСІ активні загрози/прогнози (ЖОВТІ) без винятку
        let activeTrackedAlerts = alerts.filter { $0.isActive && isRegionFiltered($0.name) }
        let activeTrackedThreats = isPremium ? alerts.filter { !($0.isActive) && $0.threatLevel != nil && isRegionFiltered($0.name) } : []
        let relevantAlerts = activeTrackedAlerts + activeTrackedThreats
        let activeNames = Set(relevantAlerts.map { $0.name })
        let activeRegions = regions.filter { activeNames.contains($0.nameUK) }
        
        var minLat: Double?
        var maxLat: Double?
        var minLon: Double?
        var maxLon: Double?

        for region in activeRegions {
            minLat = min(minLat ?? region.minLat, region.minLat)
            maxLat = max(maxLat ?? region.maxLat, region.maxLat)
            minLon = min(minLon ?? region.minLon, region.minLon)
            maxLon = max(maxLon ?? region.maxLon, region.maxLon)
        }

        if minLat == nil && !allTracked && !trackedList.isEmpty {
            let monitoredRegions = regions.filter { trackedList.contains($0.nameUK) }
            for region in monitoredRegions {
                minLat = min(minLat ?? region.minLat, region.minLat)
                maxLat = max(maxLat ?? region.maxLat, region.maxLat)
                minLon = min(minLon ?? region.minLon, region.minLon)
                maxLon = max(maxLon ?? region.maxLon, region.maxLon)
            }
        }
        
        if minLat == nil && !relevantAlerts.isEmpty {
            let lats = relevantAlerts.map { $0.coordinate.latitude }
            let lons = relevantAlerts.map { $0.coordinate.longitude }
            minLat = lats.min()
            maxLat = lats.max()
            minLon = lons.min()
            maxLon = lons.max()
        }
        
        if let minLat = minLat, let maxLat = maxLat,
           let minLon = minLon, let maxLon = maxLon {
            let centerLat = (minLat + maxLat) / 2.0
            let centerLon = (minLon + maxLon) / 2.0
            
            // Оптимальний запас для екрану iPhone без надмірного віддалення
            let rawLatDelta = max((maxLat - minLat) * 1.18, 2.2)
            let rawLonDelta = max((maxLon - minLon) * 1.18, 3.0)
            
            let latDelta = min(rawLatDelta, 5.2)
            let lonDelta = min(rawLonDelta, 7.8)
            
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
            if animated {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    self.cameraPosition = .region(region)
                }
            } else {
                self.cameraPosition = region.toCameraPosition()
            }
            return
        }
        
        // Масштаб за замовчуванням (Театр дій України без вильоту за кордон)
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.6, longitude: 31.8),
            span: MKCoordinateSpan(latitudeDelta: 5.2, longitudeDelta: 7.8)
        )
        if animated {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
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
        
        if let geoRegion = geoManager.regions.first(where: { $0.nameUK == regionName }) {
            let minLat = geoRegion.minLat
            let maxLat = geoRegion.maxLat
            let minLon = geoRegion.minLon
            let maxLon = geoRegion.maxLon
            let center = geoRegion.center
            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.5, 0.8),
                longitudeDelta: max((maxLon - minLon) * 1.5, 1.2)
            )
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                self.cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
            }
        } else if let alertReg = alerts.first(where: { $0.name == regionName }) {
            let region = MKCoordinateRegion(
                center: alertReg.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 1.2, longitudeDelta: 1.8)
            )
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
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
