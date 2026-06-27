import SwiftUI
import MapKit
import UIKit

@available(iOS 17.0, *)
struct ContentViewV4: View {
    @StateObject private var viewModel = AlertViewModelV3()
    @StateObject private var geoManager = GeoJSONManager()
    
    // Координати для Києва (як на макеті)
    let centerCoordinate = CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)
    let userCoordinate = CLLocationCoordinate2D(latitude: 50.4450, longitude: 30.5300)
    let shelterCoordinate = CLLocationCoordinate2D(latitude: 50.4520, longitude: 30.5150)
    
    // Стан для анімацій (пульсація)
    @State private var isPulsating = false
    
    // Стан для навігації та модальних вікон
    @State private var showSettings = false
    @State private var showShareSheet = false
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
                            .stroke(isPulsating ? .yellow : .yellow.opacity(0.3), style: StrokeStyle(lineWidth: 3, dash: [10, 10]))
                            .foregroundStyle(isPulsating ? .yellow.opacity(0.1) : .yellow.opacity(0.03))
                    }
                }
                
                // Радарні кільця (Епіцентр тривоги)
                Annotation("", coordinate: centerCoordinate) {
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
                
                // Маркер користувача
                Annotation("Ви", coordinate: userCoordinate) {
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
            .mapStyle(.standard(elevation: .realistic))
            .colorScheme(.dark)
            .ignoresSafeArea()
            
            // Темний та червоний градієнт-віньєтка по краях для інтенсивності тривоги
            RadialGradient(
                gradient: Gradient(colors: [.clear, .clear, .red.opacity(0.3), .red.opacity(0.8)]),
                center: .center,
                startRadius: 150,
                endRadius: 500
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            // 2. ВЕРХНІЙ БАНЕР (Імітація Dynamic Island)
            TopAlertBannerV4()
                .padding(.top, 10)
            
            // 3. НИЖНЯ ПАНЕЛЬ (Dashboard)
            VStack {
                Spacer()
                BottomDashboardV4(
                    isPulsating: isPulsating,
                    onFindShelter: {
                        isRoutingToShelter = true
                        Task {
                            let request = MKLocalSearch.Request()
                            request.naturalLanguageQuery = "метро укриття"
                            request.region = MKCoordinateRegion(center: centerCoordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
                            
                            let search = MKLocalSearch(request: request)
                            if let response = try? await search.start(), let firstItem = response.mapItems.first {
                                await MainActor.run {
                                    self.foundShelter = firstItem
                                    self.selectedShelter = firstItem
                                    
                                    withAnimation(.easeInOut(duration: 2.0)) {
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
                    },
                    onShare: {
                        showShareSheet = true
                    },
                    onSettings: {
                        showSettings = true
                    }
                )
            }
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
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
                ShelterDetailView(shelter: shelter, route: route, onRouteRequested: {
                    calculateRoute(to: shelter)
                })
                .presentationDetents([.height(250)])
            }
        }
        .onAppear {
            // Запуск безкінечної анімації
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                isPulsating = true
            }
            
            // Автовіддалення карти через пару секунд, щоб показати інші області
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
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
    
    // Функція для прокладання маршруту
    private func calculateRoute(to destination: MKMapItem) {
        let request = MKDirections.Request()
        // Симулюємо нашу позицію як центр Києва
        let sourcePlacemark = MKPlacemark(coordinate: centerCoordinate)
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = destination
        request.transportType = .walking // Або .automobile

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
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "bell.badge.fill")
                .foregroundColor(.red)
                .font(.title2)
                .symbolEffect(.bounce, options: .repeating)
            
            VStack(spacing: 2) {
                Text("ТРИВОГА")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red)
                Text("00:15:22")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.85))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.red.opacity(0.8), lineWidth: 1.5)
        )
        .shadow(color: .red.opacity(0.6), radius: 15, x: 0, y: 5)
    }
}

// MARK: - Нижня скляна панель (Dashboard)
@available(iOS 17.0, *)
struct BottomDashboardV4: View {
    var isPulsating: Bool
    var onFindShelter: () -> Void
    var onShare: () -> Void
    var onSettings: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            // Ліва частина: Статус
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .opacity(isPulsating ? 0.3 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: isPulsating)
                    
                    Text("ПОВІТРЯНА\nТРИВОГА")
                        .font(.system(size: 20, weight: .heavy, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Київ та область")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    Text("Небезпека: Балістика")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.red.opacity(0.8)) // Більш тривожний колір
                }
                .padding(.top, 4)
            }
            
            Spacer()
            
            // Права частина: Кнопки
            VStack(alignment: .trailing, spacing: 12) {
                // Маленькі іконки дій
                HStack(spacing: 20) {
                    SmallIconButtonV4(iconName: "arrow.triangle.turn.up.right.diamond.fill") {
                        onFindShelter()
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
                    Text("ЗНАЙТИ НАЙБЛИЖЧЕ\nУКРИТТЯ")
                        .font(.system(size: 12, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(red: 0.6, green: 0.7, blue: 0.9)) // Світло-синій
                        .cornerRadius(12)
                }
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
                .stroke(Color.red.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .shadow(color: .red.opacity(0.3), radius: 20, x: 0, y: 10)
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
                Button(action: onRouteRequested) {
                    Text(route == nil ? "Побудувати маршрут" : "Оновити маршрут")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                if route != nil {
                    Button(action: {
                        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
                        shelter.openInMaps(launchOptions: launchOptions)
                    }) {
                        Text("Йти (Maps)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(24)
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    ContentViewV4()
}
