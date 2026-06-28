import SwiftUI
import MapKit
import UIKit

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
        locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)
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

    let userCoordinate = CLLocationCoordinate2D(latitude: 50.4450, longitude: 30.5300)
    
    // Стан для анімацій (пульсація)
    @State private var isPulsating = false
    @State private var dummyState = false
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    private var shouldBlinkLastAlert: Bool {
        guard let timestamp = viewModel.lastViewedTimestamp else { return true }
        return Date().timeIntervalSince(timestamp) < 60
    }
    
    // Стан для навігації та модальних вікон
    @State private var showSettings = false
    @State private var showShareSheet = false
    @State private var showHistory = false
    @State private var showActiveAlerts = false
    @State private var isNavigating = false
    @State private var isRoutingToShelter = false
    
    // Стан для знайденого укриття та маршруту
    @State private var foundShelter: MKMapItem? = nil
    @State private var selectedShelter: MKMapItem? = nil
    @State private var allFoundShelters: [MKMapItem] = []
    @State private var route: MKRoute? = nil
    
    // Початкова камера - зблизька на Київ
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234),
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    )
    
    var body: some View {
        ZStack(alignment: .top) {
            // 1. ШАР КАРТИ
            Map(position: $cameraPosition, selection: $selectedShelter) {
                
                // Полігони областей з активною тривогою
                ForEach(geoManager.regions.filter { region in 
                    viewModel.alerts.contains(where: { $0.name == region.nameUK && $0.isActive })
                                }) { region in
                    let isLastAlerted = region.nameUK == viewModel.lastAlertedRegionName
                    let shouldBlink = isLastAlerted && shouldBlinkLastAlert
                    
                    ForEach(0..<region.polygons.count, id: \.self) { index in
                        MapPolygon(coordinates: region.polygons[index])
                            .stroke(
                                isLastAlerted ? 
                                    .red : 
                                    .red.opacity(0.6), 
                                lineWidth: isLastAlerted ? 3.0 : 2.0
                            )
                            .foregroundStyle(
                                isLastAlerted ? 
                                    (shouldBlink ? (isPulsating ? .red.opacity(0.75) : .red.opacity(0.35)) : .red.opacity(0.55)) : 
                                    .red.opacity(0.45)
                            )
                    }
                }

                // Полігони областей з рівнем загрози (Premium)
                if viewModel.isPremium {
                    ForEach(geoManager.regions.filter { region in
                        guard let alert = viewModel.alerts.first(where: { $0.name == region.nameUK }) else { return false }
                        return !alert.isActive && alert.threatLevel != nil
                    }) { region in
                        let alert = viewModel.alerts.first(where: { $0.name == region.nameUK })
                        let level = alert?.threatLevel ?? "none"
                        
                        let strokeColor: Color = (level == "high" || level == "critical") ? .red : .yellow
                        let fillColor: Color = (level == "high" || level == "critical") ? 
                            (isPulsating ? .red.opacity(0.55) : .red.opacity(0.25)) : 
                            .yellow.opacity(0.40)
                        
                        ForEach(0..<region.polygons.count, id: \.self) { index in
                            MapPolygon(coordinates: region.polygons[index])
                                .stroke(strokeColor, lineWidth: 2.5)
                                .foregroundStyle(fillColor)
                        }
                    }
                }
                
                // Маркер користувача
                Annotation("Ви", coordinate: locationManager.location?.coordinate ?? userCoordinate) {
                    Image(systemName: "location.north.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.green)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 5)
                }
                // Усі знайдені укриття в радіусі
                ForEach(allFoundShelters, id: \.self) { shelter in
                    Marker(shelter.name ?? "Укриття", systemImage: "figure.walk.arrival", coordinate: shelter.placemark.coordinate)
                        .tint(selectedShelter == shelter ? .green : .blue)
                        .tag(shelter)
                }
                
                // Маршрут
                if let route = route {
                    MapPolyline(route)
                        .stroke(.blue, lineWidth: 5)
                }
            }
            .mapStyle(selectedMapStyle)
            .colorScheme(.dark)
            .ignoresSafeArea()
            
            if viewModel.activeAlerts > 0 {
                RadialGradient(
                    gradient: Gradient(colors: [.clear, .clear, .red.opacity(0.3), .red.opacity(0.8)]),
                    center: .center,
                    startRadius: 150,
                    endRadius: 500
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            
            // 2. ВЕРХНІЙ БАНЕР ТА КНОПКИ КЕРУВАННЯ КАМЕРОЮ
            HStack(alignment: .center) {
                // Ліва кнопка: Показати всі тривоги (центрування на Україну)
                Button(action: {
                    let activeNames = Set(viewModel.alerts.filter { $0.isActive }.map { $0.name })
                    let activeRegions = geoManager.regions.filter { activeNames.contains($0.nameUK) }
                    
                    var allCoordinates: [CLLocationCoordinate2D] = []
                    for region in activeRegions {
                        for polygon in region.polygons {
                            allCoordinates.append(contentsOf: polygon)
                        }
                    }
                    
                    if allCoordinates.isEmpty {
                        allCoordinates = viewModel.alerts.filter { $0.isActive }.map { $0.coordinate }
                    }
                    
                    if !allCoordinates.isEmpty {
                        let lats = allCoordinates.map { $0.latitude }
                        let lons = allCoordinates.map { $0.longitude }
                        if let minLat = lats.min(), let maxLat = lats.max(),
                           let minLon = lons.min(), let maxLon = lons.max() {
                            let centerLat = (minLat + maxLat) / 2.0
                            let centerLon = (minLon + maxLon) / 2.0
                            
                            // Розрахунок дельти з безпечним відступом 30%
                            let latDelta = max(maxLat - minLat, 1.0) * 1.3
                            let lonDelta = max(maxLon - minLon, 1.5) * 1.3
                            
                            withAnimation(.easeInOut(duration: 2.0)) {
                                cameraPosition = .region(
                                    MKCoordinateRegion(
                                        center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                                        span: MKCoordinateSpan(
                                            latitudeDelta: min(latDelta, 8.0),
                                            longitudeDelta: min(lonDelta, 13.0)
                                        )
                                    )
                                )
                            }
                        }
                    } else {
                        // Якщо активних тривог немає, показуємо всю Україну
                        withAnimation(.easeInOut(duration: 2.0)) {
                            cameraPosition = .region(
                                MKCoordinateRegion(
                                    center: CLLocationCoordinate2D(latitude: 48.3794, longitude: 31.1656),
                                    span: MKCoordinateSpan(latitudeDelta: 7.5, longitudeDelta: 12.5)
                                )
                            )
                        }
                    }
                }) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                        .padding(10)
                        .background(Color.red.opacity(0.15))
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.red.opacity(0.4), lineWidth: 1))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .padding(.leading, 16)
                
                Spacer()
                
                // Центр: Баннер тривог
                TopAlertBannerV4(activeAlerts: viewModel.activeAlerts, isLoading: viewModel.isLoading)
                    .onTapGesture {
                        if viewModel.activeAlerts > 0 {
                            showActiveAlerts = true
                        }
                    }
                
                Spacer()
                
                // Права кнопка: Показати мою локацію
                Button(action: {
                    let coord = locationManager.location?.coordinate ?? userCoordinate
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
                        .foregroundColor(.red)
                        .padding(10)
                        .background(Color.red.opacity(0.15))
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.red.opacity(0.4), lineWidth: 1))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .padding(.trailing, 16)
            }
            .padding(.top, 10)
            
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
                        isPulsating: isPulsating,
                        isSearchingShelter: isRoutingToShelter,
                        transportType: $transportType,
                        onFindShelter: findNearestShelter,
                        onShare: {
                            showShareSheet = true
                        },
                        onSettings: {
                            showSettings = true
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
                AlertListOverlayView(title: "ІСТОРІЯ ТРИВОГ", color: .yellow, alerts: viewModel.alerts, filterActiveOnly: false) {
                    showHistory = false
                }
                .transition(.opacity.combined(with: .scale))
            }
            
            if showActiveAlerts {
                AlertListOverlayView(title: "АКТИВНІ ТРИВОГИ", color: .red, alerts: viewModel.alerts, filterActiveOnly: true) {
                    showActiveAlerts = false
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $showShareSheet) {
            let shareText: String = {
                if let shelter = foundShelter {
                    let lat = shelter.placemark.coordinate.latitude
                    let lon = shelter.placemark.coordinate.longitude
                    let name = shelter.name ?? ""
                    return "Увага! Повітряна тривога. Знайдено найближче укриття: \(name), координати: \(lat), \(lon)"
                } else {
                    return "Увага! Повітряна тривога. Знайдіть найближче безпечне місце."
                }
            }()
            ShareSheet(activityItems: [shareText])
        }
        .sheet(isPresented: Binding(
            get: { selectedShelter != nil },
            set: { if !$0 { selectedShelter = nil } }
        )) {
            if let shelter = selectedShelter {
                if !isNavigating {
                    ShelterDetailView(shelter: shelter, route: route, onRouteRequested: {
                        calculateRoute(to: shelter)
                    }, onStartNavigation: {
                        isNavigating = true
                        selectedShelter = nil
                        
                        if route != nil {
                            withAnimation(.easeInOut(duration: 2.0)) {
                                let coord = locationManager.location?.coordinate ?? userCoordinate
                                cameraPosition = .userLocation(
                                    followsHeading: true,
                                    fallback: .camera(MapCamera(centerCoordinate: coord, distance: 400, heading: 0, pitch: 60))
                                )
                            }
                        } else {
                            let coord = locationManager.location?.coordinate ?? userCoordinate
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
        .onReceive(NotificationCenter.default.publisher(for: .refreshAlerts)) { _ in
            viewModel.refreshAlerts()
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.8)) {
                isPulsating.toggle()
            }
        }
        .onChange(of: viewModel.lastAlertedRegionName) {
            viewModel.markLastAlertAsViewed()
        }
        .onChange(of: selectedShelter) {
            route = nil
        }
        .onAppear {
            locationManager.requestPermission()
            viewModel.markLastAlertAsViewed()
            
            // Автовіддалення карти через пару секунд, щоб показати інші області
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 4.0)) {
                    // Координати центру України
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: 49.0, longitude: 31.0),
                            span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
                        )
                    )
                }
            }

        }
    }
    
    private func findNearestShelter() {
        guard !isRoutingToShelter else { return }
        isRoutingToShelter = true

        let userLoc = centerCoordinate
        let currentRadius = transportType == .automobile ? drivingSearchRadius : walkingSearchRadius
        let radiusMeters = max(currentRadius, 0.5) * 1000
        let searchRegion = MKCoordinateRegion(center: userLoc, latitudinalMeters: radiusMeters, longitudinalMeters: radiusMeters)

        let queries = ["укриття", "бомбосховище", "shelter", "bomb shelter", "метро", "subway"]

        Task {
            var allItems: [MKMapItem] = []
            
            await withTaskGroup(of: [MKMapItem]?.self) { group in
                for query in queries {
                    group.addTask {
                        let request = MKLocalSearch.Request()
                        request.naturalLanguageQuery = query
                        request.region = searchRegion
                        let search = MKLocalSearch(request: request)
                        return try? await search.start().mapItems
                    }
                }
                
                for await items in group {
                    if let items = items {
                        allItems.append(contentsOf: items)
                    }
                }
            }

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

            // Знаходження найближчого об'єкта до користувача
            let closestItem = uniqueItems.min { a, b in
                let distA = CLLocation(latitude: a.placemark.coordinate.latitude, longitude: a.placemark.coordinate.longitude)
                    .distance(from: CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude))
                let distB = CLLocation(latitude: b.placemark.coordinate.latitude, longitude: b.placemark.coordinate.longitude)
                    .distance(from: CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude))
                return distA < distB
            }

            await MainActor.run {
                isRoutingToShelter = false
                allFoundShelters = uniqueItems
                guard let closestItem else { return }

                foundShelter = closestItem
                selectedShelter = closestItem
                route = nil

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
        let request = MKDirections.Request()
        // Симулюємо нашу позицію як центр Києва
        let sourcePlacemark = MKPlacemark(coordinate: centerCoordinate)
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = destination
        request.transportType = transportType

        Task {
            let directions = MKDirections(request: request)
            if let response = try? await directions.calculate() {
                await MainActor.run {
                    self.route = response.routes.first
                    withAnimation {
                        if let rect = self.route?.polyline.boundingMapRect {
                            cameraPosition = .rect(rect.insetBy(dx: -500, dy: -500))
                        }
                    }
                }
            }
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
    let activeAlerts: Int
    let isLoading: Bool

    private var statusColor: Color {
        activeAlerts > 0 ? .red : .green
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: activeAlerts > 0 ? "bell.badge.fill" : "checkmark.shield.fill")
                .foregroundColor(statusColor)
                .font(.title2)
                .symbolEffect(.bounce, options: .repeating, value: activeAlerts)
            
            VStack(spacing: 2) {
                Text(activeAlerts > 0 ? "ТРИВОГА" : "СПОКІЙНО")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(statusColor)
                Text(isLoading ? "ОНОВЛЕННЯ" : "\(activeAlerts) АКТИВНИХ")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(statusColor)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.85))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(statusColor.opacity(0.8), lineWidth: 1.5)
        )
        .shadow(color: statusColor.opacity(0.6), radius: 15, x: 0, y: 5)
    }
}

// MARK: - Нижня скляна панель (Dashboard)
@available(iOS 17.0, *)
struct BottomDashboardV4: View {
    let activeAlerts: Int
    let primaryRegionName: String?
    var isPulsating: Bool
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
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: isPulsating)
                    
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
                Button(action: onFindShelter) {
                    HStack(spacing: 8) {
                        if isSearchingShelter {
                            ProgressView()
                                .tint(.black)
                        }
                        Text(isSearchingShelter ? "ШУКАЮ\nУКРИТТЯ" : "ЗНАЙТИ НАЙБЛИЖЧЕ\nУКРИТТЯ")
                            .font(.system(size: 12, weight: .bold))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.black)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(red: 0.6, green: 0.7, blue: 0.9))
                    .cornerRadius(12)
                }
                .disabled(isSearchingShelter)
            }
        }
        .padding(20)
        // Ефект "Матового скла"
        .background(.ultraThinMaterial)
        // Більш темний фон для контрасту
        .background(Color.black.opacity(0.6))
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(statusColor.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .shadow(color: statusColor.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// Допоміжний компонент для дрібних кнопок
@available(iOS 17.0, *)
struct SmallIconButtonV4: View {
    let iconName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
        }
    }
}

// Допоміжний компонент для Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Вигляд деталей укриття
@available(iOS 17.0, *)
struct ShelterDetailView: View {
    let shelter: MKMapItem
    let route: MKRoute?
    let onRouteRequested: () -> Void
    let onStartNavigation: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(shelter.name ?? "Невідоме укриття")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let address = shelter.placemark.title {
                Text(address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let route = route {
                HStack {
                    Image(systemName: "figure.walk")
                        .foregroundColor(.blue)
                    Text("Відстань: \(String(format: "%.0f", route.distance)) м")
                    Spacer()
                    Text("Час: \(String(format: "%.0f", route.expectedTravelTime / 60)) хв")
                }
                .font(.subheadline)
                .padding(.top, 5)
            }
            
            Spacer()
            
            HStack(spacing: 15) {
                if route == nil {
                    Button(action: onRouteRequested) {
                        HStack {
                            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                            Text("Побудувати маршрут")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue.opacity(0.85))
                        .clipShape(Capsule())
                    }
                } else {
                    Button(action: onStartNavigation) {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Почати навігацію")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green.opacity(0.85))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(24)
        .background(Color.clear) // Ensure we don't accidentally make it opaque
    }
}

#Preview {
    ContentView()
}

@available(iOS 17.0, *)
struct NavigationOverlay: View {
    let route: MKRoute?
    let onEndNavigation: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "location.north.line.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Режим навігації")
                        .font(.headline)
                        .foregroundColor(.white)
                    if let route = route {
                        Text("\(String(format: "%.0f", route.distance)) м • \(String(format: "%.0f", route.expectedTravelTime / 60)) хв пішки")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
            }
            
            Button(action: onEndNavigation) {
                Text("Завершити навігацію")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.85))
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .preferredColorScheme(.dark)
        .padding()
    }
}

extension MKDirectionsTransportType: @retroactive Hashable {}

@available(iOS 17.0, *)
struct AlertListOverlayView: View {
    let title: String
    let color: Color
    let alerts: [AlertRegion]
    let filterActiveOnly: Bool
    var onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                Text(title)
                    .font(.system(size: 30, weight: .black, design: .default))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.8), radius: 10, x: 0, y: 0)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(color)
                        .padding(10)
                        .shadow(color: color.opacity(0.8), radius: 10, x: 0, y: 0)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            
            // List of alerts (dimmed background)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    let filteredAlerts = filterActiveOnly ? alerts.filter { $0.isActive } : alerts
                    let sortedAlerts = filteredAlerts.sorted { a, b in
                        if a.isActive != b.isActive {
                            return a.isActive
                        }
                        return (a.lastChanged ?? "") > (b.lastChanged ?? "")
                    }
                    
                    ForEach(sortedAlerts) { alert in
                        HStack(alignment: .center, spacing: 12) {
                            Circle()
                                .fill(alert.isActive ? color : color.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .shadow(color: color, radius: alert.isActive ? 4 : 0)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alert.name)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(color)
                                    .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 0)
                                
                                HStack(spacing: 8) {
                                    Text(alert.isActive ? "АКТИВНА" : "НЕАКТИВНА")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundColor(alert.isActive ? color : color.opacity(0.6))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .border(alert.isActive ? color : color.opacity(0.6), width: 1)
                                    
                                    if let changed = alert.lastChanged {
                                        Text(changed)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(color.opacity(0.7))
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85).ignoresSafeArea())
    }
}

