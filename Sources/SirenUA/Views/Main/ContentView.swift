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
        case .settings:           return "settings"
        case .admin:              return "admin"
        case .share:              return "share"
        case .shelterDetail(let item):
            return "shelter_\(item.placemark.coordinate.latitude)_\(item.placemark.coordinate.longitude)"
        }
    }
}

// MARK: - ContentView
// Extensions live in:
//   ContentView+Theme.swift      — themeColor, themeStatusText, themeActiveCount, hasAlerts/hasThreats, filter helpers
//   ContentView+MapLayers.swift  — alertsDict, activeAlertRegions, activeThreatRegions, selectedMapStyle
//   ContentView+Sheets.swift     — sheetContent(for:), locationButton, handleOpenRegionDetail

struct ContentView: View {
    @StateObject var viewModel = AlertViewModelV3()
    @StateObject var geoManager = GeoJSONManager()
    @StateObject var locationManager = LocationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var mapViewModel = MapViewModel()
    
    @AppStorage("showRadar") private var showRadar = true
    @AppStorage("mapType") var mapType = 0
    @AppStorage("walkingSearchRadius") private var walkingSearchRadius = 1.5
    @AppStorage("drivingSearchRadius") private var drivingSearchRadius = 5.0
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @AppStorage("adminAuthenticated") private var adminAuthenticated = false
    
    var centerCoordinate: CLLocationCoordinate2D {
        locationManager.location?.coordinate ?? Self.fallbackCoordinate
    }

    var alertFocusCoordinate: CLLocationCoordinate2D {
        trackedAlerts.first(where: { $0.isActive })?.coordinate ?? primaryThreatRegion?.coordinate ?? centerCoordinate
    }

    static let fallbackCoordinate = CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)

    var currentUserCoordinate: CLLocationCoordinate2D {
        locationManager.location?.coordinate ?? Self.fallbackCoordinate
    }

    @State private var timeRefreshTrigger = Date()
    private let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    private var shouldBlinkLastAlert: Bool {
        guard let timestamp = viewModel.lastViewedTimestamp else { return true }
        return Date().timeIntervalSince(timestamp) < 60
    }
    
    @AppStorage("allRegionsTracked") private var allRegionsTracked = true
    @AppStorage("trackedRegionsString") private var trackedRegionsString = ""
    @State private var showRegionPickerSheet = false
    @State private var showBottomOperationalToast = false

    private func isRegionTracked(_ name: String) -> Bool {
        if allRegionsTracked { return true }
        let list = trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }
        if list.isEmpty { return true }
        return list.contains(name)
    }

    private var trackedAlerts: [AlertRegion] {
        return viewModel.alerts.filter { isRegionTracked($0.name) }
    }

    @State private var currentHeroEventIndex = 0

    private var activeThreatTrackedRegions: [AlertRegion] {
        let list = trackedAlerts.filter { !($0.activeThreats.isEmpty) || ($0.threatLevel != nil) || $0.isActive }
        return list.isEmpty ? trackedAlerts : list
    }

    private var primaryThreatRegion: AlertRegion? {
        let regions = activeThreatTrackedRegions
        guard !regions.isEmpty else { return nil }
        let index = currentHeroEventIndex % regions.count
        return regions[index]
    }

    private let allRegionsList = [
        "Вінницька область",    "Волинська область",       "Дніпропетровська область",
        "Донецька область",     "Житомирська область",     "Закарпатська область",
        "Запорізька область",   "Івано-Франківська область","Київська область",
        "м. Київ",              "Кіровоградська область",  "Луганська область",
        "Львівська область",    "Миколаївська область",    "Одеська область",
        "Полтавська область",   "Рівненська область",      "Сумська область",
        "Тернопільська область","Харківська область",      "Херсонська область",
        "Хмельницька область",  "Черкаська область",       "Чернівецька область",
        "Чернігівська область"
    ]

    private var trackedRegionsSet: Set<String> {
        Set(trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty })
    }

    private func selectAllRegions() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            allRegionsTracked = true
        }
        NotificationManager.shared.syncTopicSubscriptions()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func toggleTrackedRegion(_ name: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            var currentList = trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }
            
            if allRegionsTracked {
                allRegionsTracked = false
                currentList = [name]
            } else {
                if currentList.contains(name) {
                    currentList.removeAll { $0 == name }
                } else {
                    currentList.append(name)
                }
            }
            
            if currentList.isEmpty {
                allRegionsTracked = true
            } else {
                allRegionsTracked = false
            }
            
            trackedRegionsString = currentList.joined(separator: ";")
        }
        NotificationManager.shared.syncTopicSubscriptions()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func handleConfirmRegionSelection() {
        NotificationManager.shared.syncTopicSubscriptions()
        let list = trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }
        if !allRegionsTracked && list.count == 1 {
            mapViewModel.focusOnSingleRegion(regionName: list[0], geoManager: geoManager, alerts: viewModel.alerts)
        }
    }

    private var primaryHeaderRegionLabel: String {
        if allRegionsTracked {
            let activeOrLast = primaryThreatRegion?.name ?? viewModel.lastAlertedRegionName ?? "м. Київ"
            return "УСІ ОБЛАСТІ • \(activeOrLast)"
        } else {
            let list = trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }
            if list.count == 1 {
                return "ОБРАНА: \(list[0])"
            } else if list.count > 1 {
                if let threatReg = primaryThreatRegion?.name {
                    return "ОБРАНІ (\(list.count)) • \(threatReg)"
                } else {
                    return "ОБРАНІ ОБЛАСТІ (\(list.count))"
                }
            } else {
                return "УСІ ОБЛАСТІ"
            }
        }
    }

    private var primaryThreatDetail: String? {
        primaryThreatRegion?.currentThreat?.detail ?? primaryThreatRegion?.threatDetail
    }

    private var primaryThreatType: String? {
        primaryThreatRegion?.currentThreat?.type ?? primaryThreatRegion?.threatType
    }

    private var primaryThreatConfidence: Int? {
        primaryThreatRegion?.currentThreat?.confidence ?? primaryThreatRegion?.threatConfidence
    }

    private var primaryThreatETA: String? {
        primaryThreatRegion?.displayETA
    }

    private func getShortThreatDesc(_ type: String?) -> String {
        guard let type = type else { return "Загроза" }
        return viewModel.getThreatTypeDescriptionShort(type)
    }

    private func handleRegionSelection(_ region: AlertRegion) {
        mapViewModel.selectedRegionForDetail = region
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .top) {
            // 1. ШАР КАРТИ (Повне відображення загроз по всій Україні)
            Map(
                position: $mapViewModel.cameraPosition,
                bounds: MapCameraBounds(minimumDistance: 100, maximumDistance: 3_000_000),
                interactionModes: .all,
                selection: $mapViewModel.selectedShelter
            ) {
                ThreatMapContent(
                    safeRegions: safeRegions,
                    activeThreatRegions: activeThreatRegions,
                    activeAlertRegions: activeAlertRegions,
                    alertsDict: alertsDict,
                    alerts: viewModel.alerts, // Всі загрози на карті України
                    isPremium: viewModel.isPremium,
                    lastAlertedRegionName: viewModel.lastAlertedRegionName,
                    allFoundShelters: mapViewModel.allFoundShelters,
                    selectedShelter: mapViewModel.selectedShelter,
                    route: mapViewModel.route,
                    timeRefreshTrigger: timeRefreshTrigger,
                    currentUserCoordinate: currentUserCoordinate,
                    zoomScale: mapViewModel.elementZoomScale,
                    getThreatTypeDescriptionShort: getShortThreatDesc,
                    onRegionSelected: handleRegionSelection
                )
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                mapViewModel.updateCameraDistance(context.camera.distance)
            }
            .mapStyle(selectedMapStyle)
            .colorScheme(.dark)
            .ignoresSafeArea()
            
            // Синій атмосферний фон карти (Balanced Deep Blue Ambient Glow Overlay)
            ZStack {
                Color(red: 0.01, green: 0.06, blue: 0.22)
                    .opacity(0.22)
                
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.12, blue: 0.35).opacity(0.30),
                        Color.clear,
                        Color(red: 0.01, green: 0.08, blue: 0.28).opacity(0.35)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            // Динамічна верхня та нижня підсвітка екрану
            ambientGlowOverlay
            
            // 2. ВЕРХНІЙ БАНЕР ТА ШІ-РАДАР (З ОПЕРАТИВНИМ МОНІТОРИНГОМ)
            topBannerSection
            
            // 3. НИЖНЯ ПАНЕЛЬ, КАСКАДНІ СПОВІЩЕННЯ ТА ТАББАР
            VStack(spacing: 10) {
                if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage)
                        .padding(.horizontal, 20)
                        .padding(.top, 90)
                }

                // Spacer for map navigation
                Spacer()
                
                if mapViewModel.isNavigating {
                    NavigationOverlay(route: mapViewModel.route) {
                        mapViewModel.isNavigating = false
                        mapViewModel.route = nil
                        mapViewModel.selectedShelter = nil
                    }
                } else {
                    // Плаваючі прозорі кнопки зліва (Локація) та справа (Концентрація областей в рамки екрана)
                    mapFloatingControls
                        .padding(.bottom, 2)

                    // Каскадне нижнє оперативне сповіщення (динамічно з'являється та зникає)
                    if showBottomOperationalToast, let alert = primaryThreatRegion {
                        OperationalMonitoringCardView(
                            regionName: alert.name,
                            threatDetail: alert.currentThreat?.detail ?? alert.threatDetail,
                            confidence: alert.currentThreat?.confidence ?? alert.threatConfidence ?? 92,
                            updatedAt: "щойно",
                            isAlarm: alert.isActive,
                            onClose: {
                                withAnimation(.easeOut(duration: 0.35)) {
                                    showBottomOperationalToast = false
                                }
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture {
                            mapViewModel.showActiveAlerts = true
                        }
                    }
                    
                    // Нижній полупрозорий дашборд з локацією, ШІ-концентрацією та пошуком бомбосховища
                    bottomDashboardSection

                    // Нижній таббар
                    MainTabBarView(selectedTab: $mapViewModel.selectedTab)
                }
            }
            .padding(.bottom, 12)
            
            if mapViewModel.showHistory {
                AlertListOverlayView(
                    title: "ІСТОРІЯ ТРИВОГ (Всі області)",
                    color: .yellow,
                    alerts: viewModel.alerts,
                    filterMode: .all,
                    filterActiveOnly: false,
                    isPremium: viewModel.isPremium,
                    onSelect: { region in
                        mapViewModel.selectedRegionForHistory = region
                        mapViewModel.showHistory = false
                    },
                    onClose: { mapViewModel.showHistory = false }
                )
                .transition(.opacity.combined(with: .scale))
            }
            
            if mapViewModel.showActiveAlerts {
                AlertListOverlayView(
                    title: "ПОДІЇ ЗА СУТКУ (24 ГОД)",
                    color: themeColor,
                    alerts: viewModel.alerts,
                    filterMode: .last24Hours,
                    filterActiveOnly: false,
                    isPremium: viewModel.isPremium,
                    onSelect: { region in
                        mapViewModel.selectedRegionForDetail = region
                        mapViewModel.showActiveAlerts = false
                    },
                    onClose: { mapViewModel.showActiveAlerts = false }
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .sheet(item: $mapViewModel.activeSheet) { item in
            sheetContent(for: item)
        }
        .sheet(item: $mapViewModel.selectedRegionForDetail) { region in
            AlertRegionDetailView(region: region)
                .environmentObject(viewModel)
        }
        .sheet(item: $mapViewModel.selectedRegionForHistory) { region in
            NavigationStack {
                RegionHistoryView(regionName: region.name, themeColor: region.color)
                    .environmentObject(viewModel)
            }
        }
        .sheet(isPresented: $showRegionPickerSheet) {
            RegionSelectionSheet(
                allRegionsTracked: $allRegionsTracked,
                trackedRegionsString: $trackedRegionsString,
                onConfirm: { handleConfirmRegionSelection() }
            )
        }
        .tabHandlers(mapViewModel: mapViewModel)
        .onReceive(NotificationCenter.default.publisher(for: .refreshAlerts)) { _ in
            viewModel.refreshAlerts()
        }
        .onChange(of: trackedRegionsString) { _, _ in
            NotificationManager.shared.syncTopicSubscriptions()
        }
        .onChange(of: allRegionsTracked) { _, _ in
            NotificationManager.shared.syncTopicSubscriptions()
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
        .mapStateHandlers(
            viewModel: viewModel,
            mapViewModel: mapViewModel,
            geoManager: geoManager,
            onboardingCompleted: $onboardingCompleted
        )
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
                triggerMapCenter()
            }
        }
        .onReceive(refreshTimer) { _ in
            timeRefreshTrigger = Date()
            if activeThreatTrackedRegions.count > 1 {
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentHeroEventIndex = (currentHeroEventIndex + 1) % activeThreatTrackedRegions.count
                }
            }
        }
    }

    private func triggerMapCenter(animated: Bool = false) {
        mapViewModel.centerMapOnAlerts(
            alerts: viewModel.alerts,
            isPremium: viewModel.isPremium,
            lastAlertedRegionName: viewModel.lastAlertedRegionName,
            regions: geoManager.regions,
            animated: animated
        )
    }

    @ViewBuilder
    private var ambientGlowOverlay: some View {
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
                    .frame(height: 180)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // MARK: Top Banner Section
    @ViewBuilder
    private var topBannerSection: some View {
        VStack(spacing: 8) {
            AIRadarHeroCardView(
                primaryRegionLabel: primaryHeaderRegionLabel,
                activeThreatCount: trackedAlerts.filter({ $0.isActive || $0.threatLevel != nil }).count,
                isAlarmActive: trackedAlerts.contains(where: { $0.isActive }),
                threatDetail: primaryThreatDetail,
                threatType: primaryThreatType,
                confidence: primaryThreatConfidence,
                eta: primaryThreatETA,
                isTrackedOnly: !allRegionsTracked,
                allRegionsList: allRegionsList,
                trackedRegionsSet: trackedRegionsSet,
                allRegionsTracked: allRegionsTracked,
                onOpenRegionPicker: { showRegionPickerSheet = true },
                onCardTap: {
                    if let targetRegion = primaryThreatRegion?.name {
                        mapViewModel.focusOnSingleRegion(regionName: targetRegion, geoManager: geoManager, alerts: viewModel.alerts)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
            )
            .padding(.top, 6)
            
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
    }

    private var dashboardPrimaryRegionName: String {
        if let regName = primaryThreatRegion?.name {
            return regName
        }
        if let activeName = trackedAlerts.first(where: { $0.isActive })?.name {
            return activeName
        }
        return "м. Київ"
    }

    // MARK: Bottom Dashboard Section
    @ViewBuilder
    private var bottomDashboardSection: some View {
        BottomDashboardV4(
            activeAlerts: trackedAlerts.filter { $0.isActive }.count,
            primaryRegionName: dashboardPrimaryRegionName,
            isSearchingShelter: mapViewModel.isRoutingToShelter,
            transportType: $mapViewModel.transportType,
            onFindShelter: {
                mapViewModel.findNearestShelter(
                    userLoc: currentUserCoordinate,
                    walkingSearchRadius: 1.5,
                    drivingSearchRadius: 10.0,
                    serverURL: NetworkManager.serverURL,
                    presentSheet: true
                )
            },
            onShare: { mapViewModel.activeSheet = .share },
            onSettings: { mapViewModel.activeSheet = .settings },
            onHistory: { mapViewModel.showHistory = true },
            onStatusTap: { mapViewModel.showActiveAlerts = true },
            threatConfidence: primaryThreatRegion?.currentThreat?.confidence ?? primaryThreatRegion?.threatConfidence
        )
    }
}

// MARK: - Tab Handlers ViewModifier

struct ContentViewTabHandlers: ViewModifier {
    @ObservedObject var mapViewModel: MapViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: mapViewModel.selectedTab) { oldValue, newValue in
                switch newValue {
                case 0:
                    mapViewModel.showHistory = false
                    mapViewModel.showActiveAlerts = false
                case 1:
                    mapViewModel.showActiveAlerts = false
                    mapViewModel.showHistory = true
                case 2:
                    mapViewModel.showHistory = false
                    mapViewModel.showActiveAlerts = true
                case 3:
                    mapViewModel.showHistory = false
                    mapViewModel.showActiveAlerts = false
                    mapViewModel.activeSheet = .settings
                default:
                    break
                }
            }
            .onChange(of: mapViewModel.showHistory) { _, isShowing in
                if !isShowing && mapViewModel.selectedTab == 1 {
                    mapViewModel.selectedTab = 0
                }
            }
            .onChange(of: mapViewModel.showActiveAlerts) { _, isShowing in
                if !isShowing && mapViewModel.selectedTab == 2 {
                    mapViewModel.selectedTab = 0
                }
            }
            .onChange(of: mapViewModel.activeSheet) { _, activeSheet in
                if activeSheet == nil && mapViewModel.selectedTab == 3 {
                    mapViewModel.selectedTab = 0
                }
            }
    }
}

extension View {
    func tabHandlers(mapViewModel: MapViewModel) -> some View {
        modifier(ContentViewTabHandlers(mapViewModel: mapViewModel))
    }

    func mapStateHandlers(
        viewModel: AlertViewModelV3,
        mapViewModel: MapViewModel,
        geoManager: GeoJSONManager,
        onboardingCompleted: Binding<Bool>
    ) -> some View {
        modifier(ContentViewMapStateHandlers(
            viewModel: viewModel,
            mapViewModel: mapViewModel,
            geoManager: geoManager,
            onboardingCompleted: onboardingCompleted
        ))
    }
}

struct ContentViewMapStateHandlers: ViewModifier {
    @ObservedObject var viewModel: AlertViewModelV3
    @ObservedObject var mapViewModel: MapViewModel
    @ObservedObject var geoManager: GeoJSONManager
    @Environment(\.scenePhase) private var scenePhase
    @Binding var onboardingCompleted: Bool

    private func triggerMapCenter(animated: Bool = false) {
        mapViewModel.centerMapOnAlerts(
            alerts: viewModel.alerts,
            isPremium: viewModel.isPremium,
            lastAlertedRegionName: viewModel.lastAlertedRegionName,
            regions: geoManager.regions,
            animated: animated
        )
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: onboardingCompleted) { _, newValue in
                if newValue {
                    triggerMapCenter()
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    Task {
                        await viewModel.fetchThreatState()
                        triggerMapCenter(animated: true)
                    }
                }
            }
            .onChange(of: viewModel.alerts) { _, _ in
                triggerMapCenter(animated: true)
            }
            .onChange(of: geoManager.isLoaded) { _, newValue in
                if newValue {
                    triggerMapCenter()
                }
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
