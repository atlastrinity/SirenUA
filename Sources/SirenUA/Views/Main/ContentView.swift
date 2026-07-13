import SwiftUI
import MapKit
import UIKit
import OSLog

private let mapLogger = Logger(subsystem: "com.sirenua", category: "Map")

enum ActiveSheet: Identifiable, Equatable {
    case settings
    case admin
    case share
    case shelterDetail(MKMapItem)
    
    var id: String {
        switch self {
        case .settings:
            return "settings"
        case .admin:
            return "admin"
        case .share:
            return "share"
        case .shelterDetail(let item):
            return "shelter_\(item.placemark.coordinate.latitude)_\(item.placemark.coordinate.longitude)"
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = AlertViewModelV3()
    @StateObject private var geoManager = GeoJSONManager()
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var mapViewModel = MapViewModel()
    
    @AppStorage("showRadar") private var showRadar = true
    @AppStorage("mapType") private var mapType = 0
    @AppStorage("walkingSearchRadius") private var walkingSearchRadius = 1.5
    @AppStorage("drivingSearchRadius") private var drivingSearchRadius = 5.0
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @AppStorage("adminAuthenticated") private var adminAuthenticated = false
    
    var centerCoordinate: CLLocationCoordinate2D {
        locationManager.location?.coordinate ?? Self.fallbackCoordinate
    }

    var alertFocusCoordinate: CLLocationCoordinate2D {
        viewModel.alerts.first(where: { $0.isActive })?.coordinate ?? centerCoordinate
    }

    private var selectedMapStyle: MapStyle {
        switch mapType {
        case 1:
            return .hybrid
        case 2:
            return .imagery
        default:
            return .standard(elevation: .realistic)
        }
    }

    private static let fallbackCoordinate = CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)

    var currentUserCoordinate: CLLocationCoordinate2D {
        locationManager.location?.coordinate ?? Self.fallbackCoordinate
    }
    
    private var alertsDict: [String: AlertRegion] {
        Dictionary(uniqueKeysWithValues: viewModel.alerts.map { ($0.name, $0) })
    }
    
    private var activeAlertRegions: [RegionPolygon] {
        geoManager.regions.filter { region in
            alertsDict[region.nameUK]?.isActive == true
        }
    }
    
    private var activeThreatRegions: [RegionPolygon] {
        guard viewModel.isPremium else { return [] }
        return geoManager.regions.filter { region in
            guard let alert = alertsDict[region.nameUK] else { return false }
            return !alert.isActive && alert.threatLevel != nil
        }
    }
    
    @State private var timeRefreshTrigger = Date()
    private let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    private var shouldBlinkLastAlert: Bool {
        guard let timestamp = viewModel.lastViewedTimestamp else { return true }
        return Date().timeIntervalSince(timestamp) < 60
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // 1. ШАР КАРТИ
            Map(position: $mapViewModel.cameraPosition, selection: $mapViewModel.selectedShelter) {
                ThreatMapContent(
                    activeThreatRegions: activeThreatRegions,
                    activeAlertRegions: activeAlertRegions,
                    alertsDict: alertsDict,
                    alerts: viewModel.alerts,
                    isPremium: viewModel.isPremium,
                    lastAlertedRegionName: viewModel.lastAlertedRegionName,
                    allFoundShelters: mapViewModel.allFoundShelters,
                    selectedShelter: mapViewModel.selectedShelter,
                    route: mapViewModel.route,
                    timeRefreshTrigger: timeRefreshTrigger,
                    currentUserCoordinate: currentUserCoordinate,
                    getThreatTypeDescriptionShort: { viewModel.getThreatTypeDescriptionShort($0) },
                    onRegionSelected: { region in
                        mapViewModel.selectedRegionForDetail = region
                    }
                )
            }
            .mapStyle(selectedMapStyle)
            .colorScheme(.dark)
            .ignoresSafeArea()
            .sheet(item: $mapViewModel.selectedRegionForDetail) { region in
                AlertRegionDetailView(region: region)
            }
            
            // Динамічна верхня та нижня підсвітка екрану
            Group {
                if hasAlerts || hasThreats {
                    ZStack {
                        VStack {
                            LinearGradient(
                                colors: [themeColor.opacity(hasAlerts ? 0.30 : 0.20), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 160)
                            Spacer()
                        }
                        
                        VStack {
                            Spacer()
                            LinearGradient(
                                colors: [.clear, themeColor.opacity(hasAlerts ? 0.40 : 0.25)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 200)
                        }
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            }
            
            // 2. ВЕРХНІЙ БАНЕР ТА КНОПКИ КЕРУВАННЯ КАМЕРОЮ
            VStack(spacing: 12) {
                HStack(alignment: .center) {
                    Button(action: {
                        mapViewModel.centerMapOnAlerts(
                            alerts: viewModel.alerts,
                            isPremium: viewModel.isPremium,
                            lastAlertedRegionName: viewModel.lastAlertedRegionName,
                            regions: geoManager.regions
                        )
                    }) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(themeColor)
                            .padding(10)
                            .background(themeColor.opacity(0.15))
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(themeColor.opacity(0.4), lineWidth: 1))
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    })
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    TopAlertBannerV4(
                        statusColor: themeColor,
                        statusText: themeStatusText,
                        activeCount: themeActiveCount,
                        isLoading: viewModel.isLoading
                    )
                    .onTapGesture {
                        if themeActiveCount > 0 {
                            mapViewModel.showActiveAlerts = true
                        }
                    }
                    
                    Spacer()
                    
                    locationButton
                }
                .padding(.top, 10)
                
                if let displayMessage = mapViewModel.routeErrorMessage ?? mapViewModel.shelterInfoMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.title3)
                        
                        Text(displayMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                mapViewModel.routeErrorMessage = nil
                                mapViewModel.shelterInfoMessage = nil
                            }
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.system(size: 10, weight: .bold))
                                .padding(6)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            
            // 3. НИЖНЯ ПАНЕЛЬ АБО НАВІГАЦІЯ
            VStack {
                if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage)
                        .padding(.horizontal, 20)
                        .padding(.top, 90)
                }

                Spacer()
                if mapViewModel.isNavigating {
                    NavigationOverlay(route: mapViewModel.route) {
                        mapViewModel.isNavigating = false
                        mapViewModel.route = nil
                        mapViewModel.selectedShelter = nil
                    }
                } else {
                    BottomDashboardV4(
                        activeAlerts: viewModel.activeAlerts,
                        primaryRegionName: viewModel.alerts.first(where: { $0.isActive })?.name,
                        isSearchingShelter: mapViewModel.isRoutingToShelter,
                        transportType: $mapViewModel.transportType,
                        onFindShelter: {
                            mapViewModel.findNearestShelter(
                                userLoc: centerCoordinate,
                                walkingSearchRadius: walkingSearchRadius,
                                drivingSearchRadius: drivingSearchRadius,
                                serverURL: viewModel.threatServerURL
                            )
                        },
                        onShare: {
                            mapViewModel.activeSheet = .share
                        },
                        onSettings: {
                            mapViewModel.activeSheet = .admin
                        },
                        onHistory: {
                            mapViewModel.showHistory = true
                            viewModel.markLastAlertAsViewed()
                        },
                        onStatusTap: {
                            if viewModel.activeAlerts > 0 {
                                mapViewModel.showActiveAlerts = true
                            }
                        }
                    )
                }
            }
            .padding(.bottom, 20)
            
            if mapViewModel.showHistory {
                AlertListOverlayView(
                    title: "ІСТОРІЯ ТРИВОГ",
                    color: .yellow,
                    alerts: viewModel.alerts,
                    filterActiveOnly: false,
                    isPremium: viewModel.isPremium,
                    onSelect: { region in
                        mapViewModel.selectedRegionForDetail = region
                        mapViewModel.showHistory = false
                    },
                    onClose: {
                        mapViewModel.showHistory = false
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
            
            if mapViewModel.showActiveAlerts {
                AlertListOverlayView(
                    title: hasAlerts ? "АКТИВНІ ТРИВОГИ" : "АКТИВНІ ЗАГРОЗИ",
                    color: themeColor,
                    alerts: viewModel.alerts,
                    filterActiveOnly: true,
                    isPremium: viewModel.isPremium,
                    onSelect: { region in
                        mapViewModel.selectedRegionForDetail = region
                        mapViewModel.showActiveAlerts = false
                    },
                    onClose: {
                        mapViewModel.showActiveAlerts = false
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .sheet(item: $mapViewModel.activeSheet) { item in
            sheetContent(for: item)
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshAlerts)) { _ in
            viewModel.refreshAlerts()
        }
        .onChange(of: viewModel.lastAlertedRegionName) { _, _ in
            viewModel.markLastAlertAsViewed()
        }
        .onChange(of: mapViewModel.selectedShelter) { oldValue, newValue in
            if let newValue = newValue {
                mapViewModel.activeSheet = .shelterDetail(newValue)
            } else {
                if !mapViewModel.isNavigating {
                    mapViewModel.route = nil
                    mapViewModel.routeErrorMessage = nil
                    mapViewModel.isCalculatingRoute = false
                }
            }
        }
        .onChange(of: mapViewModel.activeSheet) { oldValue, newValue in
            if newValue == nil {
                mapViewModel.selectedShelter = nil
                if !mapViewModel.isNavigating {
                    mapViewModel.route = nil
                    mapViewModel.routeErrorMessage = nil
                    mapViewModel.isCalculatingRoute = false
                }
            }
        }
        .onChange(of: mapViewModel.transportType) { _, _ in
            if mapViewModel.selectedShelter != nil || mapViewModel.route != nil {
                mapViewModel.findNearestShelter(
                    userLoc: centerCoordinate,
                    walkingSearchRadius: walkingSearchRadius,
                    drivingSearchRadius: drivingSearchRadius,
                    serverURL: viewModel.threatServerURL
                )
            }
        }
        .onChange(of: walkingSearchRadius) { _, _ in
            if mapViewModel.selectedShelter != nil || mapViewModel.route != nil {
                mapViewModel.findNearestShelter(
                    userLoc: centerCoordinate,
                    walkingSearchRadius: walkingSearchRadius,
                    drivingSearchRadius: drivingSearchRadius,
                    serverURL: viewModel.threatServerURL
                )
            }
        }
        .onChange(of: drivingSearchRadius) { _, _ in
            if mapViewModel.selectedShelter != nil || mapViewModel.route != nil {
                mapViewModel.findNearestShelter(
                    userLoc: centerCoordinate,
                    walkingSearchRadius: walkingSearchRadius,
                    drivingSearchRadius: drivingSearchRadius,
                    serverURL: viewModel.threatServerURL
                )
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !onboardingCompleted },
            set: { onboardingCompleted = !$0 }
        )) {
            RegionOnboardingView()
        }
        .onChange(of: onboardingCompleted) { oldValue, newValue in
            if newValue {
                mapViewModel.centerMapOnAlerts(
                    alerts: viewModel.alerts,
                    isPremium: viewModel.isPremium,
                    lastAlertedRegionName: viewModel.lastAlertedRegionName,
                    regions: geoManager.regions
                )
            }
        }
        .onChange(of: geoManager.isLoaded) { oldValue, newValue in
            if newValue {
                mapViewModel.centerMapOnAlerts(
                    alerts: viewModel.alerts,
                    isPremium: viewModel.isPremium,
                    lastAlertedRegionName: viewModel.lastAlertedRegionName,
                    regions: geoManager.regions
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenRegionDetail")), perform: handleOpenRegionDetail)
        .onAppear {
            locationManager.requestPermission()
            viewModel.markLastAlertAsViewed()

            if let pending = NotificationManager.shared.pendingTappedRegion {
                if let region = viewModel.alerts.first(where: { $0.name == pending }) {
                    mapViewModel.selectedRegionForDetail = region
                }
                NotificationManager.shared.pendingTappedRegion = nil
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                mapViewModel.centerMapOnAlerts(
                    alerts: viewModel.alerts,
                    isPremium: viewModel.isPremium,
                    lastAlertedRegionName: viewModel.lastAlertedRegionName,
                    regions: geoManager.regions
                )
            }
        }
        .onReceive(refreshTimer) { _ in
            timeRefreshTrigger = Date()
        }
    }
    
    @ViewBuilder
    private func sheetContent(for item: ActiveSheet) -> some View {
        switch item {
        case .settings:
            SettingsView()
                .presentationBackground(.clear)
        case .admin:
            AdminDashboardView()
        case .share:
            let shareText: String = {
                if let shelter = mapViewModel.foundShelter {
                    let lat = shelter.placemark.coordinate.latitude
                    let lon = shelter.placemark.coordinate.longitude
                    let name = shelter.name ?? ""
                    return "🚨 Увага! Повітряна тривога.\nЗнайдено найближче укриття: \(name)\nКоординати: \(String(format: "%.5f", lat)), \(String(format: "%.5f", lon))"
                } else {
                    return "🚨 Увага! Повітряна тривога.\nЗнайдіть найближче безпечне місце."
                }
            }()
            ShareSheet(activityItems: [shareText])
        case .shelterDetail(let shelter):
            if !mapViewModel.isNavigating {
                ShelterDetailView(
                    shelter: shelter,
                    route: mapViewModel.route,
                    isCalculatingRoute: mapViewModel.isCalculatingRoute,
                    routeErrorMessage: mapViewModel.routeErrorMessage,
                    onRouteRequested: {
                        mapViewModel.calculateRoute(from: centerCoordinate, to: shelter)
                    },
                    onStartNavigation: {
                        mapViewModel.isNavigating = true
                        mapViewModel.activeSheet = nil
                        
                        if mapViewModel.route != nil {
                            withAnimation(.easeInOut(duration: 2.0)) {
                                let coord = currentUserCoordinate
                                mapViewModel.cameraPosition = .userLocation(
                                    followsHeading: true,
                                    fallback: .camera(MapCamera(centerCoordinate: coord, distance: 400, heading: 0, pitch: 60))
                                )
                            }
                        } else {
                            let coord = currentUserCoordinate
                            mapViewModel.cameraPosition = .userLocation(
                                fallback: .camera(MapCamera(centerCoordinate: coord, distance: 1000, heading: 0, pitch: 0))
                            )
                        }
                    }
                )
                .presentationDetents([.height(220)])
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(24)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(220)))
                .preferredColorScheme(.dark)
            }
        }
    }
    
    private func isRegionFiltered(_ name: String) -> Bool {
        let allTracked = UserDefaults.standard.object(forKey: "allRegionsTracked") as? Bool ?? true
        let trackedString = UserDefaults.standard.object(forKey: "trackedRegionsString") as? String ?? ""
        let trackedList = trackedString.components(separatedBy: ";")
        return allTracked || trackedList.contains(name)
    }
    
    private var activeTrackedAlerts: [AlertRegion] {
        viewModel.alerts.filter { $0.isActive && isRegionFiltered($0.name) }
    }
    
    private var activeTrackedThreats: [AlertRegion] {
        guard viewModel.isPremium else { return [] }
        return viewModel.alerts.filter { !($0.isActive) && $0.threatLevel != nil && isRegionFiltered($0.name) }
    }
    
    private var hasAlerts: Bool {
        !activeTrackedAlerts.isEmpty
    }
    
    private var hasThreats: Bool {
        !activeTrackedThreats.isEmpty
    }
    
    private var themeColor: Color {
        if hasAlerts {
            return .red
        } else if hasThreats {
            if activeTrackedThreats.contains(where: { $0.color == .red }) {
                return .red
            } else if activeTrackedThreats.contains(where: { $0.color == .orange }) {
                return .orange
            } else {
                return .yellow
            }
        } else {
            return .green
        }
    }
    
    private var themeActiveCount: Int {
        hasAlerts ? activeTrackedAlerts.count : (hasThreats ? activeTrackedThreats.count : 0)
    }
    
    private var themeStatusText: String {
        hasAlerts ? "ТРИВОГА" : (hasThreats ? "ЗАГРОЗА" : "СПОКІЙНО")
    }
    
    private func handleOpenRegionDetail(_ notification: Notification) {
        guard let regionName = notification.userInfo?["regionName"] as? String else { return }
        if let region = viewModel.alerts.first(where: { $0.name == regionName }) {
            mapViewModel.selectedRegionForDetail = region
        }
    }
    
    private var locationButton: some View {
        Button(action: {
            let coord = currentUserCoordinate
            withAnimation(.easeInOut(duration: 1.0)) {
                mapViewModel.cameraPosition = .region(
                    MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                )
            }
        }) {
            Image(systemName: "location.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(themeColor)
                .padding(10)
                .background(themeColor.opacity(0.15))
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(themeColor.opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .simultaneousGesture(TapGesture().onEnded {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        })
        .padding(.trailing, 16)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
