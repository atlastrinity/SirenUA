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
                    withAnimation(.easeInOut(duration: 1.2)) {
                        self.cameraPosition = .region(region)
                    }
                } else {
                    self.cameraPosition = region.toCameraPosition()
                }
                return
            }
        }
        
        // Масштаб за замовчуванням (Театр дій України без вильоту за кордон)
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.6, longitude: 31.8),
            span: MKCoordinateSpan(latitudeDelta: 5.2, longitudeDelta: 7.8)
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
