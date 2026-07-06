import SwiftUI
import MapKit

@available(iOS 16.0, *)
struct iOS16FallbackView: View {
    @StateObject private var viewModel = AlertViewModelV3()
    @StateObject private var geoManager = GeoJSONManager()
    @State private var showSettings = false
    @State private var selectedRegionForDetail: AlertRegion?
    @EnvironmentObject var storeManager: StoreKitManager

    // Haptic Feedback Helper
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background dark theme
                Color(red: 0.05, green: 0.05, blue: 0.08)
                    .ignoresSafeArea()
                
                // Subtle top/bottom radial gradients for premium feel
                VStack {
                    RadialGradient(
                        colors: [statusThemeColor.opacity(0.12), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 300
                    )
                    .frame(height: 250)
                    Spacer()
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Live Status Banner
                        statusBannerView

                        // 2. Premium Paywall Banner (if not premium)
                        if !storeManager.isPremium {
                            premiumPromoBanner
                        }

                        // 3. Search Radius indicator if location is active
                        if let location = LocationManager.shared.location {
                            nearestSheltersSummaryView(userLoc: location.coordinate)
                        }

                        // 4. Region Alert List Header
                        HStack {
                            Text("Стан по областях")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(viewModel.alerts.count) регіонів")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)

                        // 5. Region List Cards
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.alerts) { region in
                                regionCard(region)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("SirenUA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        triggerHaptic()
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(storeManager)
            }
            .sheet(item: $selectedRegionForDetail) { region in
                if #available(iOS 17.0, *) {
                    AlertRegionDetailView(region: region)
                } else {
                    // Simpler iOS 16 fallback detail presentation
                    iOS16DetailView(region: region)
                }
            }
            .onAppear {
                viewModel.refreshAlerts()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private var statusThemeColor: Color {
        let hasAlerts = viewModel.alerts.contains { $0.isActive }
        let hasThreats = viewModel.alerts.contains { !$0.isActive && $0.threatLevel != nil }
        
        if hasAlerts {
            return .red
        } else if hasThreats {
            return .yellow
        } else {
            return .green
        }
    }

    private var statusBannerView: some View {
        let hasAlerts = viewModel.alerts.contains { $0.isActive }
        let hasThreats = viewModel.alerts.contains { !$0.isActive && $0.threatLevel != nil }
        let activeCount = viewModel.alerts.filter { $0.isActive }.count
        let threatCount = viewModel.alerts.filter { !$0.isActive && $0.threatLevel != nil }.count

        return VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hasAlerts ? "ПОВІТРЯНА ТРИВОГА" : (hasThreats ? "ЗАГРОЗА АТАКИ" : "СИТУАЦІЯ СТАБІЛЬНА"))
                        .font(.system(size: 20, weight: .black, design: .default))
                        .foregroundColor(statusThemeColor)
                    
                    Text(hasAlerts ? "Активна в \(activeCount) областях" : (hasThreats ? "Виявлено загроз: \(threatCount)" : "Спокійного неба над головою"))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                
                Image(systemName: hasAlerts ? "exclamationmark.triangle.fill" : (hasThreats ? "bell.fill" : "checkmark.seal.fill"))
                    .font(.system(size: 32))
                    .foregroundColor(statusThemeColor)
            }
            .padding()
            .background(Color.white.opacity(0.04))
            .background(.ultraThinMaterial)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(statusThemeColor.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: statusThemeColor.opacity(0.1), radius: 10, y: 4)
            .padding(.horizontal)
        }
    }

    private var premiumPromoBanner: some View {
        Button(action: {
            triggerHaptic()
            showSettings = true // Opens settings where they can subscribe
        }) {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Активуйте SirenUA Premium")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Слідкуйте за напрямком ракет, Шахедів та типом загрози наживо за $0.99.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.yellow.opacity(0.15), Color.orange.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }

    private func nearestSheltersSummaryView(userLoc: CLLocationCoordinate2D) -> some View {
        HStack {
            Image(systemName: "figure.walk.arrival")
                .foregroundColor(.green)
                .font(.headline)
            Text("Поруч є укриття. Відкрийте деталі області для навігації.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func regionCard(_ region: AlertRegion) -> some View {
        let isThreat = !region.isActive && region.threatLevel != nil
        
        return Button(action: {
            triggerHaptic()
            selectedRegionForDetail = region
        }) {
            HStack(spacing: 16) {
                // Colored indicator circle
                Circle()
                    .fill(region.isActive ? Color.red : (isThreat ? Color.yellow : Color.green.opacity(0.5)))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(region.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if region.isActive {
                        Text("Повітряна тривога")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if isThreat {
                        if viewModel.isPremium {
                            Text("Загроза: \(region.threatDetail ?? "уточнюється")")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        } else {
                            Text("⚠️ Виявлено загрозу (Premium)")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    } else {
                        Text("Немає тривоги")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding()
            .background(Color.white.opacity(0.02))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

@available(iOS 16.0, *)
struct iOS16DetailView: View {
    let region: AlertRegion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Alert Icon/State
                    Image(systemName: region.isActive ? "exclamationmark.triangle.fill" : (region.threatLevel != nil ? "bell.fill" : "checkmark.circle.fill"))
                        .font(.system(size: 72))
                        .foregroundColor(region.isActive ? .red : (region.threatLevel != nil ? .yellow : .green))
                        .padding(.top, 40)
                    
                    Text(region.name)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text(region.isActive ? "АКТИВНА ТРИВОГА" : (region.threatLevel != nil ? "ЗАГРОЗА" : "СПОКІЙНО"))
                        .font(.headline)
                        .foregroundColor(region.isActive ? .red : (region.threatLevel != nil ? .yellow : .green))
                    
                    if let detail = region.threatDetail {
                        Text(detail)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text(region.description)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    Button("Зрозуміло") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.large)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Деталі")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрити") {
                        dismiss()
                    }
                }
            }
        }
    }
}
