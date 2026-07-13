import SwiftUI
import UIKit
import OSLog
import CryptoKit
import SafariServices

// MARK: - Logger
private let settingsLogger = Logger(subsystem: "com.sirenua", category: "Settings")

// MARK: - SettingsView
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("notificationsEnabled")      private var notificationsEnabled      = true
    @AppStorage("mapType")                   private var mapType                   = 0
    @AppStorage("walkingSearchRadius")       private var walkingSearchRadius       = 1.5
    @AppStorage("drivingSearchRadius")       private var drivingSearchRadius       = 5.0
    @AppStorage("allRegionsTracked")         private var allRegionsTracked         = true
    @AppStorage("trackedRegionsString")      private var trackedRegionsString      = ""
    @AppStorage("adminAuthenticated")        private var adminAuthenticated        = false
    @AppStorage("adminViewMode")             private var adminViewMode             = false
    @AppStorage("muteThreatsSound")         private var muteThreatsSound          = false

    @State private var inputEmail = ""
    @State private var inputPassword = ""
    @State private var loginErrorMessage: String? = nil
    @State private var showingAdminPanel = false

    @EnvironmentObject var storeManager: StoreKitManager
    @State private var isPurchasing     = false
    @State private var isRegionsExpanded = false
    @State private var isInitialized     = false

    enum ServerStatus: Equatable {
        case checking
        case online(label: String)
        case offline(error: String)
    }
    @State private var alertsServerStatus:  ServerStatus = .checking
    @State private var threatsServerStatus: ServerStatus = .checking
    @State private var geminiServerStatus:  ServerStatus = .checking
    // MARK: Region list
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

    // MARK: Region helpers
    private func isTracked(_ name: String) -> Bool {
        guard !trackedRegionsString.isEmpty || !allRegionsTracked else { return true }
        return trackedRegionsString.components(separatedBy: ";").contains(name)
    }

    private func setTracked(_ name: String, isOn: Bool) {
        var list = trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }
        if isOn {
            if !list.contains(name) { list.append(name) }
        } else {
            list.removeAll { $0 == name }
        }
        trackedRegionsString = list.joined(separator: ";")
    }

    // MARK: Haptics
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    // MARK: Server ping
    private func checkServerStatus() async {
        // Delay slightly to let the sheet transition animation complete smoothly
        try? await Task.sleep(nanoseconds: 350_000_000)
        
        alertsServerStatus  = .checking
        threatsServerStatus = .checking
        geminiServerStatus  = .checking

        async let alertsPing  = ping(url: "https://ubilling.net.ua/aerialalerts/", method: "HEAD")
        async let threatsPing = ping(url: "https://sirenua-threatserver.onrender.com/api/threats", method: "GET")
        async let geminiPing  = checkGeminiStatus()

        alertsServerStatus  = await alertsPing
        threatsServerStatus = await threatsPing
        geminiServerStatus  = await geminiPing
    }

    private func checkGeminiStatus() async -> ServerStatus {
        guard let url = URL(string: "https://sirenua-threatserver.onrender.com/api/gemini/status") else {
            return .offline(error: "Невірна URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        do {
            let start = Date()
            let (data, response) = try await URLSession.shared.data(for: request)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            
            if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String {
                    if status == "ok" {
                        return .online(label: "Активний (\(ms) ms)")
                    } else if status == "mock" {
                        return .online(label: "Mock режим")
                    } else {
                        let errMsg = (json["error"] as? String) ?? "Помилка ШІ"
                        return .offline(error: errMsg)
                    }
                }
                return .online(label: "Активний (\(ms) ms)")
            }
            return .offline(error: "HTTP помилка")
        } catch {
            return .offline(error: error.localizedDescription)
        }
    }

    private func ping(url urlString: String, method: String) async -> ServerStatus {
        guard let url = URL(string: urlString) else { return .offline(error: "Невірна URL") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 5.0
        do {
            let start = Date()
            let (_, response) = try await URLSession.shared.data(for: request)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                return .online(label: "\(ms) ms")
            }
            return .offline(error: "HTTP помилка")
        } catch {
            return .offline(error: error.localizedDescription)
        }
    }

    private func triggerScenario(_ scenario: String) {
        guard let url = URL(string: "https://sirenua-threatserver.onrender.com/api/threats/scenario") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["scenario": scenario]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    settingsLogger.info("Successfully triggered scenario \(scenario)")
                    // Refresh server status to update UI immediately
                    await checkServerStatus()
                } else {
                    settingsLogger.error("Failed to trigger scenario: invalid response")
                }
            } catch {
                settingsLogger.error("Error triggering scenario: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background
            backgroundLayer
            
            VStack(spacing: 0) {
                settingsHeader
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        notificationsCard
                        mapCard
                        premiumCard
                        regionsCard
                        aboutCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAdminPanel) {
            AdminDashboardView()
        }
        .onAppear {
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                await checkServerStatus()
                isInitialized = true
            }
        }
        .onChange(of: trackedRegionsString) { oldValue, newValue in
            guard isInitialized else { return }
            NotificationManager.shared.syncTopicSubscriptions()
        }
        .onChange(of: allRegionsTracked) { oldValue, newValue in
            guard isInitialized else { return }
            NotificationManager.shared.syncTopicSubscriptions()
        }
    }

    // MARK: - Background
    private var backgroundLayer: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.10)
                .ignoresSafeArea()
            
            // Top glow (Blue mixed with Yellow/Gold, transitioning to transparent)
            VStack {
                LinearGradient(
                    colors: [
                        Color.siBlue.opacity(0.22),
                        Color.siGold.opacity(0.10),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            // Bottom glow (Blue transitioning to transparent)
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.siBlue.opacity(0.20)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // MARK: - Header
    private var settingsHeader: some View {
        ZStack {
            // Glassmorphism layer
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [Color.siBlue.opacity(0.18), Color.siGold.opacity(0.12)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    // Ukraine flag top stripe (subtle)
                    VStack(spacing: 0) {
                        Color(red: 0.0, green: 0.48, blue: 0.87).opacity(0.25)
                            .frame(height: 2)
                        Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.25)
                            .frame(height: 2)
                        Spacer()
                    }
                )
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.white.opacity(0.12)),
                    alignment: .bottom
                )

            HStack(alignment: .center, spacing: 12) {
                // Shield icon
                Image(systemName: "shield.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.siBlue, Color.siBlue.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.siBlue.opacity(0.5), radius: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Налаштування")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("SirenUA")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }

                Spacer()


                if adminAuthenticated {
                    Button(action: {
                        haptic(.medium)
                        showingAdminPanel = true
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "gauge.with.needle.fill")
                            Text("Адмінка")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.siPurple)
                        .clipShape(Capsule())
                        .shadow(color: Color.siPurple.opacity(0.4), radius: 8, x: 0, y: 3)
                    }
                }

                Button(action: {
                    haptic(.medium)
                    dismiss()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Готово")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.siBlue)
                    .clipShape(Capsule())
                    .shadow(color: Color.siBlue.opacity(0.4), radius: 8, x: 0, y: 3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(height: 68)
    }

    // MARK: - Cards

    private var notificationsCard: some View {
        SettingsCard(title: "Сповіщення", icon: "bell.badge.fill", iconColor: .siBlue) {
            StyledToggleRow(
                title: "Увімкнути сповіщення",
                subtitle: "Push-повідомлення про тривоги",
                icon: "bell.fill",
                iconColor: .siBlue,
                isOn: $notificationsEnabled
            )
            
            StyledDivider()
            
            StyledToggleRow(
                title: "Без звуку для загроз",
                subtitle: "Вимкнути звук для попереджень",
                icon: "speaker.slash.circle.fill",
                iconColor: .siOrange,
                isOn: $muteThreatsSound
            )
        }
    }

    private var mapCard: some View {
        SettingsCard(title: "Карта та Навігація", icon: "map.fill", iconColor: .siBlue) {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Тип карти")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                } icon: {
                    Image(systemName: "square.3.layers.3d")
                        .foregroundColor(.siBlue)
                        .font(.system(size: 12))
                }

                Picker("Тип карти", selection: $mapType) {
                    Text("Стандартна").tag(0)
                    Text("Гібридна").tag(1)
                    Text("Супутник").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: mapType) { oldValue, newValue in haptic() }
            }

            StyledDivider()

            radiusRow(
                title: "Радіус пошуку пішки",
                icon: "figure.walk",
                iconColor: .siBlue,
                value: $walkingSearchRadius,
                range: 0.5...3.0,
                step: 0.5,
                format: "%.1f"
            )

            radiusRow(
                title: "Радіус пошуку авто",
                icon: "car.fill",
                iconColor: .siGold,
                value: $drivingSearchRadius,
                range: 1.0...20.0,
                step: 1.0,
                format: "%.0f"
            )
        }
    }

    private func radiusRow(
        title: String,
        icon: String,
        iconColor: Color,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(value.wrappedValue, specifier: format) км")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(iconColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(iconColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            Slider(value: value, in: range, step: step)
                .tint(iconColor)
        }
    }

    private var premiumCard: some View {
        SettingsCard(title: "SirenUA Premium", icon: "crown.fill", iconColor: .siGold) {
            if storeManager.isPremium {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(
                            LinearGradient(colors: [.siBlue, .siGold], startPoint: .top, endPoint: .bottom)
                        )
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Premium Активовано")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text("Всі функції розблоковано")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                }
                StyledDivider()
                Button(action: {
                    storeManager.debugResetPremium()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                        Text("Скинути преміум (для тестування)")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red)
                }
                .padding(.vertical, 4)
            } else {
                premiumUpgradeView
            }
        }
    }

    private var premiumUpgradeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Розширені можливості:")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            VStack(spacing: 8) {
                premiumFeatureRow(icon: "antenna.radiowaves.left.and.right", text: "Моніторинг загроз (Сервер)", color: .siBlue)
                premiumFeatureRow(icon: "eye.fill",                          text: "Деталізація загроз",         color: .siGold)
            }

            if let product = storeManager.storeProducts.first(where: { $0.id == "com.sirenua.premium.monthly" }) {
                Button(action: {
                    isPurchasing = true
                    Task {
                        do { _ = try await storeManager.purchase(product) }
                        catch { settingsLogger.error("Purchase failed: \(error.localizedDescription)") }
                        isPurchasing = false
                    }
                }) {
                    HStack(spacing: 8) {
                        if isPurchasing {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 13))
                            Text("Оформити підписку — \(product.displayPrice)/міс")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.siBlue, .siGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.siBlue.opacity(0.3), radius: 10, x: 0, y: 4)
                }
                .disabled(isPurchasing)

                Button("Відновити покупки") {
                    Task { await storeManager.restorePurchases() }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.siBlue)
                .frame(maxWidth: .infinity)
            } else {
                ProgressView("Завантаження продуктів...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Divider().background(Color.white.opacity(0.08))
            
            Button(action: {
                haptic(.medium)
                storeManager.debugEnablePremium()
            }) {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Активувати Premium (для тестування)")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.siGold)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
    }

    private func premiumFeatureRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var regionsCard: some View {
        SettingsCard(title: "Відслідковувані регіони", icon: "map.circle.fill", iconColor: .siGold) {
            StyledToggleRow(
                title: "Усі регіони України",
                subtitle: "Отримувати тривоги по всій країні",
                icon: "globe.europe.africa.fill",
                iconColor: .siGold,
                isOn: Binding(
                    get: { allRegionsTracked },
                    set: { newVal in
                        haptic()
                        allRegionsTracked = newVal
                        trackedRegionsString = newVal ? allRegionsList.joined(separator: ";") : ""
                    }
                )
            )

            if !allRegionsTracked {
                StyledDivider()
                regionsPickerSection
            }
        }
    }

    private var regionsPickerSection: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isRegionsExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: isRegionsExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(.siGold)
                        .font(.system(size: 16))
                    Text("Вибрати регіони вручну")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                    Spacer()
                    let count = trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }.count
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.siGold)
                            .clipShape(Capsule())
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isRegionsExpanded {
                VStack(spacing: 0) {
                    ForEach(allRegionsList, id: \.self) { region in
                        HStack {
                            Text(region)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { isTracked(region) },
                                set: { isOn in
                                    haptic()
                                    setTracked(region, isOn: isOn)
                                }
                            ))
                            .labelsHidden()
                            .tint(.siGold)
                        }
                        .padding(.vertical, 9)
                        .padding(.horizontal, 4)

                        if region != allRegionsList.last {
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var diagnosticsCard: some View {
        SettingsCard(title: "Діагностика з'єднання", icon: "wifi.router.fill", iconColor: .siBlue) {
            VStack(spacing: 12) {
                ServerStatusRow(
                    name: "Основний сервер тривог",
                    url: "ubilling.net.ua",
                    status: alertsServerStatus
                )

                Divider().background(Color.white.opacity(0.06))

                ServerStatusRow(
                    name: "Сервер загроз (Premium)",
                    url: "sirenua-threatserver.onrender.com",
                    status: threatsServerStatus
                )

                Divider().background(Color.white.opacity(0.06))

                ServerStatusRow(
                    name: "Аналізатор ШІ (Gemini)",
                    url: "gemini-2.5-flash",
                    status: geminiServerStatus
                )


                HStack {
                    Spacer()
                    Button(action: {
                        haptic(.medium)
                        alertsServerStatus  = .checking
                        threatsServerStatus = .checking
                        geminiServerStatus  = .checking
                        Task { await checkServerStatus() }
                    }) {
                        Label("Оновити статус", systemImage: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.siBlue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(Color.siBlue.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.siBlue.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var adminDashboardCard: some View {
        SettingsCard(title: "Панель адміністратора", icon: "crown.fill", iconColor: .siPurple) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Повний нативний моніторинг SirenUA: логи помилок, запити до Firebase, ліміти Gemini, правила самонавчання та симулятор загроз.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(4)
                
                Button(action: {
                    haptic(.medium)
                    showingAdminPanel = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gauge.with.needle.fill")
                        Text("Відкрити консоль управління")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.siPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.siPurple.opacity(0.3), radius: 8, x: 0, y: 3)
                }
            }
        }
    }

    private var mockScenariosCard: some View {
        SettingsCard(title: "Симуляція загроз (Розробка)", icon: "terminal.fill", iconColor: .siGold) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Запустіть один із тестових сценаріїв для перевірки жовтих областей, телеметрії, відстані та кругових діаграм ймовірностей.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .lineSpacing(4)
                
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button(action: {
                            haptic(.medium)
                            triggerScenario("shaheds_south")
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Шахеди з півдня")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.siGold.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.siGold.opacity(0.4), lineWidth: 1))
                        }
                        
                        Button(action: {
                            haptic(.medium)
                            triggerScenario("mig_takeoff")
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Зліт МіГ-31К")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.siOrange.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.siOrange.opacity(0.4), lineWidth: 1))
                        }
                    }
                    
                    HStack(spacing: 10) {
                        Button(action: {
                            haptic(.medium)
                            triggerScenario("cruise_missiles_west")
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Ракети (Захід)")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.siBlue.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.siBlue.opacity(0.4), lineWidth: 1))
                        }
                        
                        Button(action: {
                            haptic(.medium)
                            triggerScenario("clear")
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Очистити все")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.35), lineWidth: 1))
                        }
                    }
                    

                }
            }
        }
    }

    private var aboutCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.siBlue.opacity(0.3), Color.siGold.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.siBlue, .siGold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: Color.siBlue.opacity(0.4), radius: 12)

                VStack(alignment: .leading, spacing: 3) {
                    Text("SirenUA")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Версія 4.2 · Premium Edition")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
            }

            Text("Надійний локальний монітор повітряних тривог, виявлення загроз та швидкий пошук найближчих укриттів.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.55))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            StyledDivider()
            
            if adminAuthenticated {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 14))
                            .foregroundColor(.siGreen)
                        Text("Адміністратор")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            haptic(.medium)
                            adminAuthenticated = false
                            adminViewMode = false
                        }) {
                            Text("Вийти")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    Text("Ви успішно авторизовані в системі як адміністратор додатка.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Адмін Email:")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        TextField("Введіть email", text: $inputEmail)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.emailAddress)
                    }
                    
                    if !inputEmail.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                            Text("Пароль:")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.4))
                            Spacer()
                            SecureField("Введіть пароль", text: $inputPassword)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        if let error = loginErrorMessage {
                            Text(error)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.top, 2)
                        }
                        
                        Button(action: {
                            checkCredentials()
                        }) {
                            HStack {
                                Spacer()
                                Text("Увійти як Адмін")
                                    .font(.system(size: 13, weight: .bold))
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .background(Color.siBlue)
                            .cornerRadius(8)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                
                LinearGradient(
                    colors: [
                        Color.siBlue.opacity(0.06),
                        Color.siGold.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.siBlue.opacity(0.18),
                            Color.siGold.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.bottom, 8)
    }

    private func checkCredentials() {
        loginErrorMessage = nil
        
        let targetEmailHash = "d35f15d7a6fe27605bf5abd3f27edfddee174d298e71128dce76b9a231192183"
        let targetPasswordHash = "97d6b984e15431b0a67cb3d34fe0f7e6fe9fc392a7bece8b1644dc6b2b776e09"
        
        let cleanedEmail = inputEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanedPassword = inputPassword
        
        guard let emailData = cleanedEmail.data(using: .utf8),
              let passwordData = cleanedPassword.data(using: .utf8) else {
            loginErrorMessage = "Помилка кодування"
            return
        }
        
        let emailHash = SHA256.hash(data: emailData).map { String(format: "%02x", $0) }.joined()
        let passwordHash = SHA256.hash(data: passwordData).map { String(format: "%02x", $0) }.joined()
        
        if emailHash == targetEmailHash && passwordHash == targetPasswordHash {
            haptic(.medium)
            adminAuthenticated = true
            adminViewMode = true
            inputEmail = ""
            inputPassword = ""
            loginErrorMessage = nil
            showingAdminPanel = true
        } else {
            haptic(.medium)
            loginErrorMessage = "Невірний email або пароль"
        }
    }
}



