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
    
    // Стан для навігації та модальних вікон
    @State private var showSettings = false
    @State private var showShareSheet = false
    @State private var showHistory = false
    @State private var isNavigating = false
    @State private var isRoutingToShelter = false
    
    // Стан для знайденого укриття та маршруту
    @State private var foundShelter: MKMapItem? = nil
    @State private var selectedShelter: MKMapItem? = nil
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
                    ForEach(0..<region.polygons.count, id: \.self) { index in
                        MapPolygon(coordinates: region.polygons[index])
                            .stroke(isNavigating ? .yellow.opacity(0.15) : (isPulsating ? .yellow : .yellow.opacity(0.4)), lineWidth: 1.5)
                            .foregroundStyle(isNavigating ? .yellow.opacity(0.05) : (isPulsating ? .yellow.opacity(0.35) : .yellow.opacity(0.05)))
                    }
                }
                if showRadar && !isNavigating && viewModel.activeAlerts > 0 {
                    // Радарні кільця (Епіцентр тривоги)
                    Annotation("", coordinate: alertFocusCoordinate) {
                        ZStack {
                            Circle()
                                .stroke(Color.red, lineWidth: 1)
                                .frame(width: isPulsating ? 400 : 50)
                                .opacity(isPulsating ? 0 : 0.8)
                            Circle()
                                .stroke(Color.red, lineWidth: 2)
                                .frame(width: isPulsating ? 250 : 20)
                                .opacity(isPulsating ? 0 : 1)
                            Circle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: 250)
                            
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
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
                
                // Маркери тривог
                ForEach(viewModel.alerts) { alert in
                    Annotation(alert.name, coordinate: alert.coordinate) {
                        let alertColor = alert.color
                        Circle()
                            .fill(alertColor)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(color: alertColor, radius: 10)
                            .scaleEffect(isPulsating ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsating)
                    }
                }
                // Знайдене укриття
                if let shelter = foundShelter {
                    Marker(shelter.name ?? "Укриття", systemImage: "figure.walk.arrival", coordinate: shelter.placemark.coordinate)
                        .tint(.blue)
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
            
            // 2. ВЕРХНІЙ БАНЕР (Імітація Dynamic Island)
            TopAlertBannerV4(activeAlerts: viewModel.activeAlerts, isLoading: viewModel.isLoading)
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
                        }
                    )
                }
            }
            .padding(.bottom, 20)
            
            if showHistory {
                AlertHistoryOverlayView(alerts: viewModel.alerts) {
                    showHistory = false
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
                    .preferredColorScheme(.dark)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshAlerts)) { _ in
            viewModel.refreshAlerts()
        }
        .onAppear {
            locationManager.requestPermission()
            // Запуск безкінечної анімації
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                isPulsating = true
            }
            
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

        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "укриття"
            let currentRadius = transportType == .automobile ? drivingSearchRadius : walkingSearchRadius
            let radiusMeters = max(currentRadius, 0.5) * 1000
            request.region = MKCoordinateRegion(center: centerCoordinate, latitudinalMeters: radiusMeters, longitudinalMeters: radiusMeters)

            let search = MKLocalSearch(request: request)
            let firstItem = try? await search.start().mapItems.first

            await MainActor.run {
                isRoutingToShelter = false
                guard let firstItem else { return }

                foundShelter = firstItem
                selectedShelter = firstItem
                route = nil

                withAnimation(.easeInOut(duration: 1.0)) {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: firstItem.placemark.coordinate,
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
struct AlertHistoryOverlayView: View {
    let alerts: [AlertRegion]
    var onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                Text("ІСТОРІЯ ТРИВОГ")
                    .font(.system(size: 30, weight: .black, design: .default))
                    .foregroundColor(.red)
                    .shadow(color: .red.opacity(0.8), radius: 10, x: 0, y: 0)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.red)
                        .padding(10)
                        .shadow(color: .red.opacity(0.8), radius: 10, x: 0, y: 0)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            
            // List of alerts (dimmed background)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    // Show active alerts first, then non-active alerts that have a lastChanged timestamp
                    let sortedAlerts = alerts.sorted { a, b in
                        if a.isActive != b.isActive {
                            return a.isActive
                        }
                        return (a.lastChanged ?? "") > (b.lastChanged ?? "")
                    }
                    
                    ForEach(sortedAlerts) { alert in
                        HStack(alignment: .center, spacing: 12) {
                            Circle()
                                .fill(alert.isActive ? Color.red : Color.red.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .shadow(color: .red, radius: alert.isActive ? 4 : 0)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alert.name)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.red)
                                    .shadow(color: .red.opacity(0.4), radius: 4, x: 0, y: 0)
                                
                                HStack(spacing: 8) {
                                    Text(alert.isActive ? "АКТИВНА" : "НЕАКТИВНА")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundColor(alert.isActive ? .red : .red.opacity(0.6))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .border(alert.isActive ? Color.red : Color.red.opacity(0.6), width: 1)
                                    
                                    if let changed = alert.lastChanged {
                                        Text(changed)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.red.opacity(0.7))
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

