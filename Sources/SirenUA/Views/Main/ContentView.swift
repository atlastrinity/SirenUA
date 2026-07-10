import SwiftUI
import MapKit
import UIKit
import OSLog

private let mapLogger = Logger(subsystem: "com.sirenua", category: "Map")

enum ActiveSheet: Identifiable, Equatable {
    case settings
    case share
    case shelterDetail(MKMapItem)
    
    var id: String {
        switch self {
        case .settings:
            return "settings"
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
    @AppStorage("showRadar") private var showRadar = true
    @AppStorage("mapType") private var mapType = 0
    @AppStorage("walkingSearchRadius") private var walkingSearchRadius = 1.5
    @AppStorage("drivingSearchRadius") private var drivingSearchRadius = 5.0
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var transportType: MKDirectionsTransportType = .walking
    
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

    /// Fallback coordinate (Kyiv) used when GPS is unavailable
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
    
    // Стан для анімацій (пульсація)
    @State private var dummyState = false
    @State private var timeRefreshTrigger = Date()
    private let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    private var shouldBlinkLastAlert: Bool {
        guard let timestamp = viewModel.lastViewedTimestamp else { return true }
        return Date().timeIntervalSince(timestamp) < 60
    }
    
    // Стан для навігації та модальних вікон
    @State private var activeSheet: ActiveSheet? = nil
    @State private var showHistory = false
    @State private var showActiveAlerts = false
    @State private var isNavigating = false
    @State private var isRoutingToShelter = false
    @State private var selectedRegionForDetail: AlertRegion? = nil
    
    // Стан для знайденого укриття та маршруту
    @State private var foundShelter: MKMapItem? = nil
    @State private var selectedShelter: MKMapItem? = nil
    @State private var allFoundShelters: [MKMapItem] = []
    @State private var route: MKRoute? = nil
    @State private var isCalculatingRoute = false
    @State private var routeErrorMessage: String? = nil
    @State private var shelterInfoMessage: String? = nil
    
    // Початкова камера - зблизька на Київ
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234),
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    )
    
    var body: some View {
        // Розраховуємо персоналізовану тему на основі обраних користувачем областей
        let allTracked = UserDefaults.standard.object(forKey: "allRegionsTracked") as? Bool ?? true
        let trackedString = UserDefaults.standard.object(forKey: "trackedRegionsString") as? String ?? ""
        let trackedList = trackedString.components(separatedBy: ";")
        
        let isRegionFiltered: (String) -> Bool = { name in
            allTracked || trackedList.contains(name)
        }
        
        let activeTrackedAlerts = viewModel.alerts.filter { $0.isActive && isRegionFiltered($0.name) }
        let activeTrackedThreats = viewModel.isPremium ? viewModel.alerts.filter { !($0.isActive) && $0.threatLevel != nil && isRegionFiltered($0.name) } : []
        
        let hasAlerts = !activeTrackedAlerts.isEmpty
        let hasThreats = !activeTrackedThreats.isEmpty
        
        let themeColor: Color
        if hasAlerts {
            themeColor = .red
        } else if hasThreats {
            if activeTrackedThreats.contains(where: { $0.color == .red }) {
                themeColor = .red
            } else if activeTrackedThreats.contains(where: { $0.color == .orange }) {
                themeColor = .orange
            } else {
                themeColor = .yellow
            }
        } else {
            themeColor = .green
        }
        let themeActiveCount: Int = hasAlerts ? activeTrackedAlerts.count : (hasThreats ? activeTrackedThreats.count : 0)
        let themeStatusText: String = hasAlerts ? "ТРИВОГА" : (hasThreats ? "ЗАГРОЗА" : "СПОКІЙНО")

        return ZStack(alignment: .top) {
            // 1. ШАР КАРТИ
            Map(position: $cameraPosition, selection: $selectedShelter) {
                mapContent
            }
            .mapStyle(selectedMapStyle)
            .colorScheme(.dark)
            .ignoresSafeArea()
            .sheet(item: $selectedRegionForDetail) { region in
                AlertRegionDetailView(region: region)
            }
            
            // Динамічна верхня та нижня підсвітка екрану (червона - тривога, жовта - загроза)
            Group {
                if hasAlerts || hasThreats {
                    ZStack {
                        // Верхнє світіння (ідеально притиснуте до верху)
                        VStack {
                            LinearGradient(
                                colors: [themeColor.opacity(hasAlerts ? 0.30 : 0.20), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 160)
                            Spacer()
                        }
                        
                        // Нижнє світіння (ідеально притиснуте до низу)
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
                    // Ліва кнопка: Показати всі тривоги (центрування на Україну)
                    Button(action: {
                        centerMapOnAlerts()
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
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    })
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    // Центр: Баннер тривог
                    TopAlertBannerV4(
                        statusColor: themeColor,
                        statusText: themeStatusText,
                        activeCount: themeActiveCount,
                        isLoading: viewModel.isLoading
                    )
                    .onTapGesture {
                        if themeActiveCount > 0 {
                            showActiveAlerts = true
                        }
                    }
                    
                    Spacer()
                    
                    // Права кнопка: Показати мою локацію
                    Button(action: {
                        let coord = currentUserCoordinate
                        withAnimation(.easeInOut(duration: 1.0)) {
                            cameraPosition = .region(
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
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    })
                    .padding(.trailing, 16)
                }
                .padding(.top, 10)
                
                // Floating error toast banner for shelter search results
                if let displayMessage = routeErrorMessage ?? shelterInfoMessage {
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
                                routeErrorMessage = nil
                                shelterInfoMessage = nil
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
                if isNavigating {
                    NavigationOverlay(route: route) {
                        isNavigating = false
                        route = nil
                        selectedShelter = nil
                    }
                } else {
                    BottomDashboardV4(
                        activeAlerts: viewModel.activeAlerts,
                        primaryRegionName: viewModel.alerts.first(where: { $0.isActive })?.name,
                        isSearchingShelter: isRoutingToShelter,
                        transportType: $transportType,
                        onFindShelter: findNearestShelter,
                        onShare: {
                            activeSheet = .share
                        },
                        onSettings: {
                            activeSheet = .settings
                        },
                        onHistory: {
                            showHistory = true
                            viewModel.markLastAlertAsViewed()
                        },
                        onStatusTap: {
                            if viewModel.activeAlerts > 0 {
                                showActiveAlerts = true
                            }
                        }
                    )
                }
            }
            .padding(.bottom, 20)
            
            if showHistory {
                AlertListOverlayView(
                    title: "ІСТОРІЯ ТРИВОГ",
                    color: .yellow,
                    alerts: viewModel.alerts,
                    filterActiveOnly: false,
                    isPremium: viewModel.isPremium,
                    onSelect: { region in
                        selectedRegionForDetail = region
                        showHistory = false
                    },
                    onClose: {
                        showHistory = false
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
            
            if showActiveAlerts {
                AlertListOverlayView(
                    title: hasAlerts ? "АКТИВНІ ТРИВОГИ" : "АКТИВНІ ЗАГРОЗИ",
                    color: themeColor,
                    alerts: viewModel.alerts,
                    filterActiveOnly: true,
                    isPremium: viewModel.isPremium,
                    onSelect: { region in
                        selectedRegionForDetail = region
                        showActiveAlerts = false
                    },
                    onClose: {
                        showActiveAlerts = false
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .sheet(item: $activeSheet) { item in
            sheetContent(for: item)
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshAlerts)) { _ in
            viewModel.refreshAlerts()
        }
        .onChange(of: viewModel.lastAlertedRegionName) { _, _ in
            viewModel.markLastAlertAsViewed()
        }
        .onChange(of: selectedShelter) { oldValue, newValue in
            if let newValue = newValue {
                activeSheet = .shelterDetail(newValue)
            } else {
                if !isNavigating {
                    route = nil
                    routeErrorMessage = nil
                    isCalculatingRoute = false
                }
            }
        }
        .onChange(of: activeSheet) { oldValue, newValue in
            if newValue == nil {
                selectedShelter = nil
                if !isNavigating {
                    route = nil
                    routeErrorMessage = nil
                    isCalculatingRoute = false
                }
            }
        }
        .onChange(of: transportType) { _, _ in
            if selectedShelter != nil || route != nil {
                findNearestShelter()
            }
        }
        .onChange(of: walkingSearchRadius) { _, _ in
            if selectedShelter != nil || route != nil {
                findNearestShelter()
            }
        }
        .onChange(of: drivingSearchRadius) { _, _ in
            if selectedShelter != nil || route != nil {
                findNearestShelter()
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
                centerMapOnAlerts()
            }
        }
        .onChange(of: geoManager.isLoaded) { oldValue, newValue in
            if newValue {
                centerMapOnAlerts()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenRegionDetail"))) { notification in
                    if let regionName = notification.userInfo?["regionName"] as? String {
                        if let region = viewModel.alerts.first(where: { $0.name == regionName }) {
                            selectedRegionForDetail = region
                        }
                    }
                }
                .onAppear {
                    locationManager.requestPermission()
                    viewModel.markLastAlertAsViewed()

                    if let pending = NotificationManager.shared.pendingTappedRegion {
                        if let region = viewModel.alerts.first(where: { $0.name == pending }) {
                            selectedRegionForDetail = region
                        }
                        NotificationManager.shared.pendingTappedRegion = nil
                    }

                    // Автовіддалення карти через пару секунд, щоб показати інші області
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        centerMapOnAlerts()
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
        case .share:
            let shareText: String = {
                if let shelter = foundShelter {
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
            if !isNavigating {
                ShelterDetailView(shelter: shelter, route: route, isCalculatingRoute: isCalculatingRoute, routeErrorMessage: routeErrorMessage, onRouteRequested: {
                    calculateRoute(to: shelter)
                }, onStartNavigation: {
                    isNavigating = true
                    activeSheet = nil
                    
                    if route != nil {
                        withAnimation(.easeInOut(duration: 2.0)) {
                            let coord = currentUserCoordinate
                            cameraPosition = .userLocation(
                                followsHeading: true,
                                fallback: .camera(MapCamera(centerCoordinate: coord, distance: 400, heading: 0, pitch: 60))
                            )
                        }
                    } else {
                        let coord = currentUserCoordinate
                        cameraPosition = .userLocation(
                            fallback: .camera(MapCamera(centerCoordinate: coord, distance: 1000, heading: 0, pitch: 0))
                        )
                    }
                })
                .presentationDetents([.height(220)])
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(24)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(220)))
                .preferredColorScheme(.dark)
            }
        }
    }
    
    @MapContentBuilder
    private var mapContent: some MapContent {
        // Polygons
        ForEach(activeThreatRegions) { region in
            // Градієнт прозорості на основі довіри ШІ
            let threatColor = alertsDict[region.nameUK]?.color ?? .yellow
            let confidence = alertsDict[region.nameUK]?.threatConfidence ?? 75
            let strokeOpacity: Double = confidence >= 85 ? 0.8 : (confidence >= 60 ? 0.6 : 0.35)
            let fillOpacity: Double = confidence >= 85 ? 0.5 : (confidence >= 60 ? 0.35 : 0.15)
            let strokeColor: Color = threatColor.opacity(strokeOpacity)
            let fillColor: Color = threatColor.opacity(fillOpacity)
            
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(strokeColor, lineWidth: 0.5)
                    .foregroundStyle(fillColor)
            }
        }

        ForEach(activeAlertRegions) { region in
            let isLastAlerted = region.nameUK == viewModel.lastAlertedRegionName
            
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(
                        .red.opacity(0.6), 
                        lineWidth: 0.7
                    )
                    .foregroundStyle(
                        isLastAlerted ? .red.opacity(0.5) : .red.opacity(0.35)
                    )
            }
        }
        
        // User Annotation
        Annotation("Ви", coordinate: currentUserCoordinate) {
            Image(systemName: "location.north.fill")
                .foregroundColor(.white)
                .padding(8)
                .background(Color.green)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 5)
        }
        
        // Regions
        ForEach(viewModel.alerts) { alert in
            if alert.isActive || (viewModel.isPremium && alert.threatLevel != nil) {
                Annotation(coordinate: alert.coordinate) {
                    VStack(spacing: 4) {
                        Button(action: {
                            selectedRegionForDetail = alert
                        }) {
                            Image(systemName: alert.isActive ? "exclamationmark.triangle.fill" : alert.icon)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(alert.isActive ? Color.red : alert.color)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                                .shadow(radius: 3)
                        }
                        
                        // Dynamic text label with confidence and ETA
                        VStack(spacing: 1) {
                            let _ = timeRefreshTrigger // Force refresh on timer tick
                            Text(alert.name)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                            
                            if viewModel.isPremium, let type = alert.threatType {
                                Text(viewModel.getThreatTypeDescriptionShort(type))
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.yellow)
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Show confidence badge for threat zones
                            if viewModel.isPremium, alert.threatLevel != nil {
                                HStack(spacing: 3) {
                                    if let conf = alert.threatConfidence {
                                        Text("⚙️ \(conf)%")
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundColor(conf >= 85 ? .red : (conf >= 60 ? .orange : .yellow))
                                    }
                                    if let eta = alert.displayETA, !eta.isEmpty {
                                        Text(eta)
                                            .font(.system(size: 7, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                    }
                } label: {
                    EmptyView()
                }
            }
        }
        
        // Shelters
        ForEach(allFoundShelters, id: \.self) { shelter in
            Marker(shelter.name ?? "Укриття", systemImage: "figure.walk.arrival", coordinate: shelter.placemark.coordinate)
                .tint(selectedShelter == shelter ? .green : .blue)
                .tag(shelter)
        }
        
        // Route
        if let route = route {
            MapPolyline(route)
                .stroke(.blue, lineWidth: 5)
        }
    }
    
    private func findNearestShelter() {
        guard !isRoutingToShelter else {
            mapLogger.debug("Shelter search already in progress — ignoring duplicate request")
            return
        }
        isRoutingToShelter = true

        withAnimation {
            shelterInfoMessage = nil
            routeErrorMessage = nil
        }

        let userLoc = centerCoordinate
        let currentRadius = transportType == .automobile ? drivingSearchRadius : walkingSearchRadius
        let preferredRadiusMeters = max(currentRadius, 0.5) * 1000
        let maxSearchRadiusMeters = transportType == .automobile ? max(preferredRadiusMeters, 20000) : max(preferredRadiusMeters, 5000)
        
        mapLogger.info("Shelter search started. User: (\(userLoc.latitude), \(userLoc.longitude)), preferred radius: \(preferredRadiusMeters)m, max search radius: \(maxSearchRadiusMeters)m")

        Task {
            // ──────────────────────────────────────────────
            // Priority 1: Our server API (real OSM data)
            // ──────────────────────────────────────────────
            var apiShelters: [ShelterItem] = []
            do {
                let networkManager = NetworkManager()
                apiShelters = try await networkManager.fetchShelters(
                    serverURL: viewModel.threatServerURL,
                    lat: userLoc.latitude,
                    lon: userLoc.longitude,
                    radiusMeters: maxSearchRadiusMeters
                )
                mapLogger.info("API returned \(apiShelters.count) shelters")
            } catch {
                mapLogger.warning("Shelter API failed, falling back to MKLocalSearch: \(error.localizedDescription)")
            }

            if !apiShelters.isEmpty {
                // Filter shelters by preferred radius
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

                // Convert ShelterItems to MKMapItems for existing UI flow
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
                    isRoutingToShelter = false
                    allFoundShelters = mapItems
                    shelterInfoMessage = warningMsg

                    foundShelter = closestMapItem
                    selectedShelter = closestMapItem
                    route = nil
                    routeErrorMessage = nil
                    isCalculatingRoute = false
                    calculateRoute(to: closestMapItem)

                    withAnimation(.easeInOut(duration: 1.0)) {
                        cameraPosition = .region(
                            MKCoordinateRegion(
                                center: closestMapItem.placemark.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        )
                    }
                }
                return
            }

            // ──────────────────────────────────────────────
            // Priority 2: Fallback to Apple MKLocalSearch
            // ──────────────────────────────────────────────
            mapLogger.info("Falling back to MKLocalSearch...")
            let searchRegion = MKCoordinateRegion(center: userLoc, latitudinalMeters: maxSearchRadiusMeters, longitudinalMeters: maxSearchRadiusMeters)

            let queries = [
                "укриття", "бомбосховище", "shelter", "bomb shelter",
                "метро", "subway", "підземний перехід", "підвал", "паркінг"
            ]

            var allItems: [MKMapItem] = []

            await withTaskGroup(of: [MKMapItem]?.self) { group in
                for query in queries {
                    group.addTask {
                        mapLogger.debug("MKLocalSearch query: '\(query)' started")
                        let request = MKLocalSearch.Request()
                        request.naturalLanguageQuery = query
                        request.region = searchRegion
                        let search = MKLocalSearch(request: request)
                        do {
                            let response = try await search.start()
                            mapLogger.debug("Query '\(query)' returned \(response.mapItems.count) items")
                            return response.mapItems
                        } catch {
                            mapLogger.warning("Query '\(query)' failed: \(error.localizedDescription)")
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

            mapLogger.info("Total raw items found: \(allItems.count)")

            // Фільтрація дублікатів за близькістю координат (~5 метрів)
            var uniqueItems: [MKMapItem] = []
            for item in allItems {
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
            mapLogger.info("Unique items after dedup: \(uniqueItems.count)")

            // Calculate distance for each unique item
            let userLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
            let itemsWithDistance = uniqueItems.map { item -> (item: MKMapItem, distance: Double) in
                let itemLocation = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                let distance = itemLocation.distance(from: userLocation)
                return (item, distance)
            }

            // Filter items within preferred radius
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
                isRoutingToShelter = false
                
                guard let closestItem else {
                    mapLogger.warning("No shelter found within max search radius of \(maxSearchRadiusMeters)m")
                    allFoundShelters = []
                    foundShelter = nil
                    selectedShelter = nil
                    route = nil
                    routeErrorMessage = "Не знайдено жодного укриття. Спробуйте збільшити радіус у налаштуваннях."
                    isCalculatingRoute = false
                    return
                }

                mapLogger.info("Closest shelter found: \(closestItem.name ?? "unnamed")")
                allFoundShelters = displayedItems
                foundShelter = closestItem
                selectedShelter = closestItem
                route = nil
                routeErrorMessage = nil
                shelterInfoMessage = warningMsg
                isCalculatingRoute = false
                calculateRoute(to: closestItem)

                withAnimation(.easeInOut(duration: 1.0)) {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: closestItem.placemark.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                }
            }
        }
    }

    // Функція для прокладання маршруту
    private func calculateRoute(to destination: MKMapItem) {
        guard !isCalculatingRoute else { return }
        routeErrorMessage = nil
        isCalculatingRoute = true
        
        let request = MKDirections.Request()
        let sourcePlacemark = MKPlacemark(coordinate: centerCoordinate)
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
                            cameraPosition = .rect(rect.insetBy(dx: -500, dy: -500))
                        }
                    }
                }
            } catch {
                mapLogger.error("Route calculation failed: \(error.localizedDescription)")

                if request.transportType == .walking {
                    print("[ShelterSearch] Trying fallback to automobile...")
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
                                    cameraPosition = .rect(rect.insetBy(dx: -500, dy: -500))
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
    
    private func centerMapOnAlerts(animated: Bool = true) {
        let allTracked = UserDefaults.standard.object(forKey: "allRegionsTracked") as? Bool ?? true
        let trackedString = UserDefaults.standard.object(forKey: "trackedRegionsString") as? String ?? ""
        let trackedList = trackedString.components(separatedBy: ";").filter { !$0.isEmpty }
        
        let isRegionFiltered: (String) -> Bool = { name in
            allTracked || trackedList.contains(name)
        }
        
        let activeTrackedAlerts = viewModel.alerts.filter { $0.isActive && isRegionFiltered($0.name) }
        let activeTrackedThreats = viewModel.isPremium ? viewModel.alerts.filter { !($0.isActive) && $0.threatLevel != nil && isRegionFiltered($0.name) } : []
        let relevantAlerts = activeTrackedAlerts + activeTrackedThreats
        let activeNames = Set(relevantAlerts.map { $0.name })
        let activeRegions = geoManager.regions.filter { activeNames.contains($0.nameUK) }
        
        var allCoordinates: [CLLocationCoordinate2D] = []
        for region in activeRegions {
            for polygon in region.polygons {
                allCoordinates.append(contentsOf: polygon)
            }
        }
        
        if allCoordinates.isEmpty {
            allCoordinates = relevantAlerts.map { $0.coordinate }
        }
        
        // Якщо немає активних тривог/загроз в обраних регіонах, фокусуємося на самих обраних регіонах
        if allCoordinates.isEmpty {
            if !allTracked && !trackedList.isEmpty {
                let monitoredRegions = geoManager.regions.filter { trackedList.contains($0.nameUK) }
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
                
                // Використовуємо середнє значення візуальних центрів (пінів), 
                // оскільки геометричні центри полігонів можуть мати зміщення вліво/вправо
                // через складну форму областей (наприклад, "хвости" на карті).
                if !relevantAlerts.isEmpty {
                    centerLat = relevantAlerts.map { $0.coordinate.latitude }.reduce(0, +) / Double(relevantAlerts.count)
                    // Додаємо мікро-зміщення вправо (+0.05), якщо потрібно компенсувати візуальне сприйняття,
                    // але краще спочатку взяти точний візуальний центр:
                    centerLon = relevantAlerts.map { $0.coordinate.longitude }.reduce(0, +) / Double(relevantAlerts.count)
                    
                    // Щоб усі полігони влізли в екран від нового центру:
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
                        cameraPosition = .region(region)
                    }
                } else {
                    cameraPosition = .region(region)
                }
                return
            }
        }
        
        // Вся Україна
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.3794, longitude: 31.1656),
            span: MKCoordinateSpan(latitudeDelta: 7.5, longitudeDelta: 12.5)
        )
        if animated {
            withAnimation(.easeInOut(duration: 2.0)) {
                cameraPosition = .region(defaultRegion)
            }
        } else {
            cameraPosition = .region(defaultRegion)
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
