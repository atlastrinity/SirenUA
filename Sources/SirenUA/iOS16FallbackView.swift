import SwiftUI
import MapKit
import UIKit

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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenRegionDetail"))) { notification in
                            if let regionName = notification.userInfo?["regionName"] as? String {
                                if let region = viewModel.alerts.first(where: { $0.name == regionName }) {
                                    selectedRegionForDetail = region
                                }
                            }
                        }
                        .onAppear {
                            viewModel.refreshAlerts()

                            if let pending = NotificationManager.shared.pendingTappedRegion {
                                if let region = viewModel.alerts.first(where: { $0.name == pending }) {
                                    selectedRegionForDetail = region
                                }
                                NotificationManager.shared.pendingTappedRegion = nil
                            }
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
        let cardColor = region.isActive ? Color.red : (isThreat ? Color.yellow : Color.green)
        
        return Button(action: {
            triggerHaptic()
            selectedRegionForDetail = region
        }) {
            HStack(spacing: 16) {
                // Colored indicator circle with pulse/glow
                ZStack {
                    if region.isActive {
                        Circle()
                            .fill(cardColor.opacity(0.25))
                            .frame(width: 22, height: 22)
                    }
                    Circle()
                        .fill(region.isActive ? Color.red : (isThreat ? Color.yellow : Color.green.opacity(0.7)))
                        .frame(width: 10, height: 10)
                        .shadow(color: cardColor.opacity(0.5), radius: region.isActive ? 4 : 0)
                }
                .frame(width: 22)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(region.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    if region.isActive {
                        Text("🚨 Активна повітряна тривога")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                        if viewModel.isPremium, let detail = region.threatDetail {
                            Text("⚠️ \(detail)")
                                .font(.system(size: 11))
                                .foregroundColor(.yellow.opacity(0.95))
                                .lineLimit(1)
                        }
                    } else if isThreat {
                        if viewModel.isPremium {
                            Text("⚠️ Загроза: \(region.threatDetail ?? "уточнюється")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.yellow.opacity(0.9))
                        } else {
                            Text("⚠️ Виявлено загрозу (Premium)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.yellow.opacity(0.9))
                        }
                    } else {
                        Text("🟢 Немає тривоги")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green.opacity(0.75))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.3))
                    .font(.system(size: 12, weight: .bold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.02))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                cardColor.opacity(region.isActive ? 0.3 : 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        }
    }
}

@available(iOS 16.0, *)
struct iOS16DetailView: View {
    let region: AlertRegion
    @Environment(\.dismiss) private var dismiss

    private var statusThemeColor: Color {
        if region.isActive {
            return .red
        } else if region.threatLevel != nil {
            return .yellow
        } else {
            return .green
        }
    }

    private var statusIcon: String {
        if region.isActive {
            return "exclamationmark.triangle.fill"
        } else if region.threatLevel != nil {
            return "bell.badge.fill"
        } else {
            return "checkmark.shield.fill"
        }
    }

    private var statusText: String {
        if region.isActive {
            return "ПОВІТРЯНА ТРИВОГА"
        } else if region.threatLevel != nil {
            return "ЗАГРОЗА АТАКИ"
        } else {
            return "БЕЗПЕЧНО"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background dark theme
                Color(red: 0.05, green: 0.05, blue: 0.08)
                    .ignoresSafeArea()
                
                // State glow background
                VStack {
                    RadialGradient(
                        colors: [statusThemeColor.opacity(0.15), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 350
                    )
                    .frame(height: 300)
                    Spacer()
                }
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // Large animated/glowing state icon
                    ZStack {
                        Circle()
                            .fill(statusThemeColor.opacity(0.08))
                            .frame(width: 140, height: 140)
                        Circle()
                            .stroke(statusThemeColor.opacity(0.2), lineWidth: 1.5)
                            .frame(width: 120, height: 120)

                        Image(systemName: statusIcon)
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(statusThemeColor)
                            .shadow(color: statusThemeColor.opacity(0.4), radius: 10)
                    }

                    // Region Card Details
                    VStack(spacing: 12) {
                        Text(region.name)
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text(statusText)
                            .font(.system(size: 13, weight: .bold))
                            .tracking(2.0)
                            .foregroundColor(statusThemeColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(statusThemeColor.opacity(0.15))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(statusThemeColor.opacity(0.3), lineWidth: 1))
                    }

                    // Description / Threat details
                    VStack(alignment: .center, spacing: 14) {
                        if let detail = region.threatDetail {
                            Text("ДЕТАЛІ ЗАГРОЗИ")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.yellow.opacity(0.7))
                            Text(detail)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        } else {
                            Text("ОПИС СТАНУ")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                            Text(region.description)
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                    Spacer()

                    // Close Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                    }) {
                        Text("Зрозуміло")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [statusThemeColor.opacity(0.8), statusThemeColor.opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: statusThemeColor.opacity(0.35), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Деталі регіону")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Text("Закрити")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
    }
}
