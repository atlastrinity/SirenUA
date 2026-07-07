import SwiftUI
import MapKit
import UIKit
import OSLog

private let mapLogger = Logger(subsystem: "com.sirenua", category: "Map")

@available(iOS 17.0, *)
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

@available(iOS 17.0, *)
struct ContentView: View {
    @StateObject private var viewModel = AlertViewModelV3()
    @StateObject private var geoManager = GeoJSONManager()
    @StateObject private var locationManager = LocationManager.shared
    @AppStorage("showRadar") private var showRadar = true
    @AppStorage("mapType") private var mapType = 0
    @AppStorage("walkingSearchRadius") private var walkingSearchRadius = 1.5
    @AppStorage("drivingSearchRadius") private var drivingSearchRadius = 5.0
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
        geoManager.regions.filter { region in
            guard let alert = alertsDict[region.nameUK] else { return false }
            return !alert.isActive && alert.threatLevel != nil
        }
    }
    
    // Стан для анімацій (пульсація)
    @State private var dummyState = false
    
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
        let activeTrackedThreats = viewModel.alerts.filter { !($0.isActive) && $0.threatLevel != nil && isRegionFiltered($0.name) }
        
        let hasAlerts = !activeTrackedAlerts.isEmpty
        let hasThreats = !activeTrackedThreats.isEmpty
        
        let themeColor: Color = hasAlerts ? .red : (hasThreats ? .yellow : .green)
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
                if #available(iOS 17.0, *) {
                    AlertRegionDetailView(region: region)
                }
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
                if let error = routeErrorMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.title3)
                        
                        Text(error)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                routeErrorMessage = nil
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
                    title: "АКТИВНІ ТРИВОГИ",
                    color: .red,
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
        .onAppear {
            locationManager.requestPermission()
            viewModel.markLastAlertAsViewed()
            
            // Автовіддалення карти через пару секунд, щоб показати інші області
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                centerMapOnAlerts()
            }
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
            let confidence = alertsDict[region.nameUK]?.threatConfidence ?? 75
            let strokeOpacity: Double = confidence >= 85 ? 0.8 : (confidence >= 60 ? 0.6 : 0.35)
            let fillOpacity: Double = confidence >= 85 ? 0.5 : (confidence >= 60 ? 0.35 : 0.15)
            let strokeColor: Color = .yellow.opacity(strokeOpacity)
            let fillColor: Color = .yellow.opacity(fillOpacity)
            
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
                            Image(systemName: alert.isActive ? "exclamationmark.triangle.fill" : "bell.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(alert.isActive ? Color.red : Color.yellow)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                                .shadow(radius: 3)
                        }
                        
                        // Dynamic text label with confidence and ETA
                        VStack(spacing: 1) {
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
                            if viewModel.isPremium, !alert.isActive, alert.threatLevel != nil {
                                HStack(spacing: 3) {
                                    if let conf = alert.threatConfidence {
                                        Text("⚙️ \(conf)%")
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundColor(conf >= 85 ? .red : (conf >= 60 ? .orange : .yellow))
                                    }
                                    if let eta = alert.threatETA, !eta.isEmpty {
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
                    Text(alert.name)
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

        let userLoc = centerCoordinate
        let currentRadius = transportType == .automobile ? drivingSearchRadius : walkingSearchRadius
        let radiusMeters = max(currentRadius, 0.5) * 1000
        mapLogger.info("Shelter search started. User: (\(userLoc.latitude), \(userLoc.longitude)), radius: \(radiusMeters)m")

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
                    radiusMeters: radiusMeters
                )
                mapLogger.info("API returned \(apiShelters.count) shelters")
            } catch {
                mapLogger.warning("Shelter API failed, falling back to MKLocalSearch: \(error.localizedDescription)")
            }

            if !apiShelters.isEmpty {
                // Convert ShelterItems to MKMapItems for existing UI flow
                let mapItems = apiShelters.map { shelter -> MKMapItem in
                    let placemark = MKPlacemark(coordinate: shelter.coordinate)
                    let item = MKMapItem(placemark: placemark)
                    item.name = shelter.name ?? shelter.typeDescription
                    if let addr = shelter.address {
                        item.name = "\(item.name ?? "Укриття") — \(addr)"
                    }
                    return item
                }

                await MainActor.run {
                    isRoutingToShelter = false
                    allFoundShelters = mapItems

                    guard let closest = mapItems.first else { return }
                    foundShelter = closest
                    selectedShelter = closest
                    route = nil
                    routeErrorMessage = nil
                    isCalculatingRoute = false

                    withAnimation(.easeInOut(duration: 1.0)) {
                        cameraPosition = .region(
                            MKCoordinateRegion(
                                center: closest.placemark.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        )
                    }
                }
                return;
            }

            // ──────────────────────────────────────────────
            // Priority 2: Fallback to Apple MKLocalSearch
            // ──────────────────────────────────────────────
            mapLogger.info("Falling back to MKLocalSearch...")
            let searchRegion = MKCoordinateRegion(center: userLoc, latitudinalMeters: radiusMeters, longitudinalMeters: radiusMeters)

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

            // Filter items strictly within the selected radius
            let userLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
            let strictRadiusItems = uniqueItems.filter { item in
                let itemLocation = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                return itemLocation.distance(from: userLocation) <= radiusMeters
            }
            mapLogger.info("Items within strict radius (\(radiusMeters)m): \(strictRadiusItems.count)")

            // Знаходження найближчого об'єкта до користувача
            let closestItem = strictRadiusItems.min { a, b in
                let distA = CLLocation(latitude: a.placemark.coordinate.latitude, longitude: a.placemark.coordinate.longitude)
                    .distance(from: userLocation)
                let distB = CLLocation(latitude: b.placemark.coordinate.latitude, longitude: b.placemark.coordinate.longitude)
                    .distance(from: userLocation)
                return distA < distB
            }

            await MainActor.run {
                isRoutingToShelter = false
                
                guard let closestItem else {
                    mapLogger.warning("No shelter found within strict radius of \(currentRadius) km")
                    allFoundShelters = []
                    foundShelter = nil
                    selectedShelter = nil
                    route = nil
                    routeErrorMessage = "Не знайдено жодного укриття у радіусі \(String(format: "%.1f", currentRadius)) км. Спробуйте збільшити радіус у налаштуваннях."
                    isCalculatingRoute = false
                    return
                }

                mapLogger.info("Closest strict shelter found: \(closestItem.name ?? "unnamed")")
                allFoundShelters = strictRadiusItems
                foundShelter = closestItem
                selectedShelter = closestItem
                route = nil
                routeErrorMessage = nil
                isCalculatingRoute = false

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
        let trackedList = trackedString.components(separatedBy: ";")
        
        let isRegionFiltered: (String) -> Bool = { name in
            allTracked || trackedList.contains(name)
        }
        
        let activeTrackedAlerts = viewModel.alerts.filter { $0.isActive && isRegionFiltered($0.name) }
        let activeTrackedThreats = viewModel.alerts.filter { !($0.isActive) && $0.threatLevel != nil && isRegionFiltered($0.name) }
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

@available(iOS 17.0, *)
struct AlertPinViewV4: View {
    let alert: AlertRegion
    var isPulsating: Bool
    
    var body: some View {
        ZStack {
            if alert.level >= 3 {
                Circle()
                    .fill(alert.color.opacity(0.4))
                    .frame(width: isPulsating ? 80 : 20)
                    .opacity(isPulsating ? 0 : 1)
                    .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: isPulsating)
            }
            
            Image(systemName: alert.icon)
                .font(.caption)
                .foregroundColor(.white)
                .padding(6)
                .background(alert.color)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                .shadow(radius: 4)
        }
    }
}

// MARK: - Верхній банер
@available(iOS 17.0, *)
struct TopAlertBannerV4: View {
    let statusColor: Color
    let statusText: String
    let activeCount: Int
    let isLoading: Bool

    // Computed icon based on semantic state, not color comparison
    private var statusIcon: String {
        if activeCount > 0 {
            return statusText == "ТРИВОГА" ? "bell.badge.fill" : "exclamationmark.triangle.fill"
        }
        return "checkmark.shield.fill"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.system(size: 20, weight: .bold))
                .symbolEffect(.bounce, options: .repeating, value: activeCount)
                .shadow(color: statusColor.opacity(0.5), radius: 6)

            VStack(spacing: 2) {
                Text(statusText)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(statusColor.opacity(0.9))
                    .tracking(1.5)
                Text(isLoading ? "ОНОВЛЕННЯ..." : "\(activeCount) АКТИВНИХ")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundColor(statusColor)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.75))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [statusColor.opacity(0.9), statusColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: statusColor.opacity(0.4), radius: 15, x: 0, y: 5)
    }
}

// MARK: - Нижня скляна панель (Dashboard)
@available(iOS 17.0, *)
struct BottomDashboardV4: View {
    let activeAlerts: Int
    let primaryRegionName: String?
    @State private var isPulsating = false
    let isSearchingShelter: Bool
    @Binding var transportType: MKDirectionsTransportType
    var onFindShelter: () -> Void
    var onShare: () -> Void
    var onSettings: () -> Void
    var onHistory: () -> Void
    var onStatusTap: () -> Void

    private var hasActiveAlert: Bool {
        activeAlerts > 0
    }
    
    private var statusColor: Color {
        hasActiveAlert ? .red : .green
    }
    
    private var circleOpacity: Double {
        hasActiveAlert && isPulsating ? 0.3 : 1.0
    }
    
    private var statusText: String {
        hasActiveAlert ? "ПОВІТРЯНА\nТРИВОГА" : "ТРИВОГ\nНЕМАЄ"
    }
    
    private var detailText: String {
        hasActiveAlert ? "Активних областей: \(activeAlerts)" : "Останні дані оновлено"
    }
    
    private var detailColor: Color {
        hasActiveAlert ? Color.red.opacity(0.8) : Color.green.opacity(0.8)
    }
    
    var body: some View {
        HStack(alignment: .top) {
            // Ліва частина: Статус
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                        .opacity(circleOpacity)
                    
                    Text(statusText)
                        .font(.system(size: 20, weight: .heavy, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryRegionName ?? "Україна")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    Text(detailText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(detailColor)
                }
                .padding(.top, 4)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onStatusTap()
            }
            
            Spacer()
            
            // Права частина: Кнопки
            VStack(alignment: .trailing, spacing: 12) {
                // Транспорт
                Picker("Транспорт", selection: $transportType) {
                    Image(systemName: "figure.walk").tag(MKDirectionsTransportType.walking)
                    Image(systemName: "car").tag(MKDirectionsTransportType.automobile)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                
                // Маленькі іконки дій
                HStack(spacing: 20) {
                    SmallIconButtonV4(iconName: "clock.fill") {
                        onHistory()
                    }
                    SmallIconButtonV4(iconName: "square.and.arrow.up") {
                        onShare()
                    }
                    SmallIconButtonV4(iconName: "gearshape.fill") {
                        onSettings()
                    }
                }
                
                // Головна кнопка "Знайти укриття"
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    onFindShelter()
                }) {
                    HStack(spacing: 8) {
                        if isSearchingShelter {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSearchingShelter ? "ШУКАЮ\nУКРИТТЯ" : "ЗНАЙТИ НАЙБЛИЖЧЕ\nУКРИТТЯ")
                            .font(.system(size: 12, weight: .bold))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.18, green: 0.5, blue: 0.95), Color(red: 0.5, green: 0.3, blue: 0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color(red: 0.18, green: 0.5, blue: 0.95).opacity(isPulsating ? 0.6 : 0.2), radius: isPulsating ? 8 : 4)
                }
                .disabled(isSearchingShelter)
            }
        }
        .padding(20)
        // Ефект надпрозорого преміального скла (Glassmorphism)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.04))
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
        )
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isPulsating = true
            }
        }
    }
}

// Допоміжний компонент для дрібних кнопок
@available(iOS 17.0, *)
struct SmallIconButtonV4: View {
    let iconName: String
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isPressed ? 0.25 : 0.13))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .scaleEffect(isPressed ? 0.88 : 1.0)
        }
        .buttonStyle(.plain)
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
    }
}

@available(iOS 17.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
