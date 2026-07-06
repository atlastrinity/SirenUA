import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("autoRefreshEnabled") private var autoRefreshEnabled = true
    @AppStorage("refreshInterval") private var refreshInterval = 30
    @AppStorage("mapType") private var mapType = 0
    @AppStorage("walkingSearchRadius") private var walkingSearchRadius = 1.5
    @AppStorage("drivingSearchRadius") private var drivingSearchRadius = 5.0
    
    @EnvironmentObject var storeManager: StoreKitManager
    @State private var isPurchasing = false
    @AppStorage("threatServerURL") private var threatServerURL = "https://eb3e-185-94-219-55.ngrok-free.app"
    @AppStorage("premiumDetailedNotifications") private var premiumDetailedNotifications = true
    @AppStorage("premiumUseVoiceAnnouncements") private var premiumUseVoiceAnnouncements = true
    @AppStorage("allRegionsTracked") private var allRegionsTracked = true
    @AppStorage("trackedRegionsString") private var trackedRegionsString = ""
    
    @State private var isRegionsExpanded = false

    private let allRegionsList = [
        "Вінницька область", "Волинська область", "Дніпропетровська область",
        "Донецька область", "Житомирська область", "Закарпатська область",
        "Запорізька область", "Івано-Франківська область", "Київська область",
        "м. Київ", "Кіровоградська область", "Луганська область",
        "Львівська область", "Миколаївська область", "Одеська область",
        "Полтавська область", "Рівненська область", "Сумська область",
        "Тернопільська область", "Харківська область", "Херсонська область",
        "Хмельницька область", "Черкаська область", "Чернівецька область",
        "Чернігівська область"
    ]

    private func isTracked(_ name: String) -> Bool {
        if trackedRegionsString.isEmpty && allRegionsTracked {
            return true
        }
        let list = trackedRegionsString.components(separatedBy: ";")
        return list.contains(name)
    }

    private func setTracked(_ name: String, isOn: Bool) {
        var list = trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }
        if isOn {
            if !list.contains(name) {
                list.append(name)
            }
        } else {
            list.removeAll { $0 == name }
        }
        trackedRegionsString = list.joined(separator: ";")
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    var body: some View {
        ZStack {
            // Фонові градієнти
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.1, blue: 0.15), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Навігаційна панель
                HStack {
                    Text("Налаштування")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        triggerHaptic()
                        dismiss()
                    }) {
                        Text("Готово")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding()
                .background(Color.white.opacity(0.02))
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // 1. Сповіщення
                        SettingsCard(title: "Сповіщення", icon: "bell.fill", iconColor: .red) {
                            ToggleRow(title: "Увімкнути сповіщення", isOn: $notificationsEnabled)
                            Divider().background(Color.white.opacity(0.1))
                            ToggleRow(title: "Автооновлення даних", isOn: $autoRefreshEnabled)
                            
                            if autoRefreshEnabled {
                                Divider().background(Color.white.opacity(0.1))
                                HStack {
                                    Text("Інтервал оновлення")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Stepper("\(refreshInterval) сек", value: $refreshInterval, in: 15...300, step: 15)
                                        .onChange(of: refreshInterval) { _ in triggerHaptic() }
                                }
                            }
                        }
                        
                        // 2. Карта та Навігація
                        SettingsCard(title: "Карта та Навігація", icon: "map.fill", iconColor: .blue) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Тип карти")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Picker("Тип карти", selection: $mapType) {
                                    Text("Стандартна").tag(0)
                                    Text("Гібридна").tag(1)
                                    Text("Супутник").tag(2)
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: mapType) { _ in triggerHaptic() }
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Радіус пошуку пішки")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(walkingSearchRadius, specifier: "%.1f") км")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    Slider(value: $walkingSearchRadius, in: 0.5...3.0, step: 0.5)
                                        .tint(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Радіус пошуку авто")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(drivingSearchRadius, specifier: "%.0f") км")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    Slider(value: $drivingSearchRadius, in: 1.0...20.0, step: 1.0)
                                        .tint(.blue)
                                }
                            }
                        }
                        
                        // 3. Premium Моніторинг
                        SettingsCard(title: "SirenUA Premium", icon: "crown.fill", iconColor: .yellow) {
                            if storeManager.isPremium {
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                    Text("Premium Активовано")
                                        .font(.subheadline)
                                        .bold()
                                        .foregroundColor(.white)
                                }
                                Divider().background(Color.white.opacity(0.1))
                                ToggleRow(title: "Деталізація сповіщень", isOn: $premiumDetailedNotifications)
                                Divider().background(Color.white.opacity(0.1))
                                ToggleRow(title: "Голосове озвучення (TTS)", isOn: $premiumUseVoiceAnnouncements)
                                Divider().background(Color.white.opacity(0.1))
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Адреса сервера загроз:")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    TextField("https://threats.server.com", text: $threatServerURL)
                                        .font(.system(.body, design: .monospaced))
                                        .padding(10)
                                        .background(Color.black.opacity(0.3))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                        .autocorrectionDisabled()
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Отримайте доступ до розширених функцій:")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Label("Голосові сповіщення (TTS)", systemImage: "speaker.wave.2.fill")
                                        Label("Моніторинг загроз (Сервер)", systemImage: "antenna.radiowaves.left.and.right")
                                        Label("Деталізація ракет", systemImage: "paperplane.fill")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    
                                    if let product = storeManager.storeProducts.first(where: { $0.id == "com.sirenua.premium.monthly" }) {
                                        Button(action: {
                                            isPurchasing = true
                                            Task {
                                                do {
                                                    let _ = try await storeManager.purchase(product)
                                                } catch {
                                                    print("Purchase failed: \(error)")
                                                }
                                                isPurchasing = false
                                            }
                                        }) {
                                            HStack {
                                                if isPurchasing {
                                                    ProgressView()
                                                } else {
                                                    Text("Оформити підписку — \(product.displayPrice)/міс")
                                                        .bold()
                                                }
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.yellow.opacity(0.8))
                                            .foregroundColor(.black)
                                            .cornerRadius(10)
                                        }
                                        .disabled(isPurchasing)
                                        
                                        Button("Відновити покупки") {
                                            Task {
                                                await storeManager.restorePurchases()
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity)
                                    } else {
                                        ProgressView("Завантаження...")
                                    }
                                }
                            }
                        }
                        
                        // 4. Області для попереджень (collapsible)
                        SettingsCard(title: "Області для попереджень", icon: "map.badge.ellipsis", iconColor: .purple) {
                            ToggleRow(title: "Усі області України", isOn: Binding(
                                get: { allRegionsTracked },
                                set: { trackingAll in
                                    triggerHaptic()
                                    allRegionsTracked = trackingAll
                                    if trackingAll {
                                        trackedRegionsString = allRegionsList.joined(separator: ";")
                                    } else {
                                        trackedRegionsString = ""
                                    }
                                }
                            ))
                            
                            if !allRegionsTracked {
                                Divider().background(Color.white.opacity(0.1))
                                
                                DisclosureGroup(
                                    isExpanded: $isRegionsExpanded,
                                    content: {
                                        VStack(spacing: 8) {
                                            ForEach(allRegionsList, id: \.self) { region in
                                                HStack {
                                                    Text(region)
                                                        .font(.subheadline)
                                                        .foregroundColor(.white)
                                                    Spacer()
                                                    Toggle("", isOn: Binding(
                                                        get: { isTracked(region) },
                                                        set: { isOn in
                                                            triggerHaptic()
                                                            setTracked(region, isOn: isOn)
                                                        }
                                                    ))
                                                    .labelsHidden()
                                                }
                                                .padding(.vertical, 4)
                                                
                                                if region != allRegionsList.last {
                                                    Divider().background(Color.white.opacity(0.05))
                                                }
                                            }
                                        }
                                        .padding(.top, 10)
                                    },
                                    label: {
                                        HStack {
                                            Text("Вибрати області вручну")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            withAnimation {
                                                isRegionsExpanded.toggle()
                                            }
                                        }
                                    }
                                )
                                .accentColor(.purple)
                            }
                        }
                        
                        // 5. Про додаток (Beautiful Brand Card)
                        VStack(spacing: 12) {
                            HStack(spacing: 15) {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.blue)
                                    .shadow(color: .blue.opacity(0.6), radius: 10)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("SirenUA")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text("Версія 4.2 (Premium)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            
                            Text("Надійний локальний монітор повітряних тривог, виявлення загроз та швидкий пошук найближчих укриттів.")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .background(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.bottom, 20)
                        
                    }
                    .padding()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Допоміжні компоненти

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(iconColor)
                    .cornerRadius(8)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.02))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .onChange(of: isOn) { _ in
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
}
