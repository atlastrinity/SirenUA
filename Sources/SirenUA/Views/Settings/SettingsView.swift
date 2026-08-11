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
    @ObservedObject private var settings = NotificationSettings.shared
    @AppStorage("mapType")                   private var mapType                   = 0
    @AppStorage("walkingSearchRadius")       private var walkingSearchRadius       = 1.5
    @AppStorage("drivingSearchRadius")       private var drivingSearchRadius       = 5.0
    @AppStorage("adminAuthenticated")        private var adminAuthenticated        = false
    @AppStorage("adminViewMode")             private var adminViewMode             = false

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
    // MARK: Region list — uses centralized RegionRegistry
    private var allRegionsList: [String] { RegionRegistry.allRegions }


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
        async let threatsPing = ping(url: "\(NetworkManager.serverURL)/api/threats", method: "GET")
        async let geminiPing  = checkGeminiStatus()

        alertsServerStatus  = await alertsPing
        threatsServerStatus = await threatsPing
        geminiServerStatus  = await geminiPing
    }

    private func checkGeminiStatus() async -> ServerStatus {
        guard let url = URL(string: "\(NetworkManager.serverURL)/api/gemini/status") else {
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
        guard let url = URL(string: "\(NetworkManager.serverURL)/api/threats/scenario") else { return }
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
                        if adminAuthenticated {
                            diagnosticsCard
                            adminDashboardCard
                            mockScenariosCard
                        }
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
        .onChange(of: settings.notificationsEnabled) { oldValue, newValue in
            guard isInitialized else { return }
            NotificationManager.shared.syncTopicSubscriptions()
        }
        .onChange(of: settings.trackedRegionsString) { oldValue, newValue in
            guard isInitialized else { return }
            NotificationManager.shared.syncTopicSubscriptions()
        }
        .onChange(of: settings.allRegionsTracked) { oldValue, newValue in
            guard isInitialized else { return }
            NotificationManager.shared.syncTopicSubscriptions()
        }
    }

    // MARK: - Background
    private var backgroundLayer: some View {
        ZStack {
            ChartColorTheme.bg.ignoresSafeArea()
            Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.85).ignoresSafeArea()
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.15).opacity(0.9),
                    Color(red: 0.05, green: 0.10, blue: 0.25).opacity(0.8),
                    Color(red: 0.02, green: 0.04, blue: 0.12).opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Header
    private var settingsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("⚙️ Налаштування")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .shadow(color: .green, radius: 4)
                    Text("SirenUA · Конфігурація")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
            HStack(spacing: 10) {
                if adminAuthenticated {
                    Button(action: {
                        haptic(.medium)
                        showingAdminPanel = true
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "gauge.with.needle.fill")
                                .font(.system(size: 12))
                            Text("Консоль")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.purple.opacity(0.3))
                        .clipShape(Capsule())
                    }
                }

                Button(action: {
                    haptic(.medium)
                    dismiss()
                }) {
                    Text("Готово")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.blue.opacity(0.3))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ChartColorTheme.cardBg)
    }

    // MARK: - Cards

    private var notificationsCard: some View {
        NotificationsSettingsCard(
            settings: settings,
            onHaptic: { style in haptic(style) }
        )
    }

    private var mapCard: some View {
        MapSettingsCard(
            mapType: $mapType,
            walkingSearchRadius: $walkingSearchRadius,
            drivingSearchRadius: $drivingSearchRadius
        )
    }

    private var premiumCard: some View {
        PremiumSettingsCard(
            isPurchasing: $isPurchasing,
            onHaptic: { style in haptic(style) }
        )
    }

    private var regionsCard: some View {
        RegionTrackingCard(
            settings: settings,
            isRegionsExpanded: $isRegionsExpanded,
            onHaptic: { style in haptic(style) }
        )
    }

    private var diagnosticsCard: some View {
        ServerDiagnosticsCard(
            alertsServerStatus: alertsServerStatus,
            threatsServerStatus: threatsServerStatus,
            geminiServerStatus: geminiServerStatus,
            onRefresh: {
                haptic(.medium)
                alertsServerStatus  = .checking
                threatsServerStatus = .checking
                geminiServerStatus  = .checking
                Task { await checkServerStatus() }
            }
        )
    }

    private var adminDashboardCard: some View {
        SettingsCard(title: "Панель адміністратора", icon: "gauge.with.needle.fill", iconColor: .red) {
            Text("Повний нативний моніторинг SirenUA: логи помилок, запити до Firebase, ліміти Gemini, правила самонавчання та симулятор загроз.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .lineSpacing(4)
            
            Button(action: {
                haptic(.medium)
                showingAdminPanel = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "gauge.with.needle.fill")
                    Text("Відкрити консоль управління")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
    }

    private var mockScenariosCard: some View {
        MockScenariosCard(onTriggerScenario: { scenario in
            haptic(.medium)
            triggerScenario(scenario)
        })
    }

    private var aboutCard: some View {
        SettingsCard(title: "Про додаток", icon: "shield.lefthalf.filled.badge.checkmark", iconColor: ChartColorTheme.accent) {
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 22))
                    .foregroundColor(ChartColorTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("SirenUA")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Версія 4.2 · Premium Edition")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
            }

            Text("Надійний локальний монітор повітряних тривог, виявлення загроз та швидкий пошук найближчих укриттів.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .lineSpacing(4)
            
            StyledDivider()
            
            if adminAuthenticated {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(ChartColorTheme.confirmed)
                            .frame(width: 6, height: 6)
                            .shadow(color: ChartColorTheme.confirmed, radius: 4)
                        Text("Адміністратор")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button(action: {
                        haptic(.medium)
                        adminAuthenticated = false
                        adminViewMode = false
                    }) {
                        Text("Вийти")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ChartColorTheme.overestimated)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(ChartColorTheme.overestimated.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("Адмін Email:")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        TextField("Введіть email", text: $inputEmail)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.emailAddress)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(8)
                    
                    if !inputEmail.isEmpty {
                        HStack(spacing: 8) {
                            Text("Пароль:")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            SecureField("Введіть пароль", text: $inputPassword)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                        
                        if let error = loginErrorMessage {
                            Text(error)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(ChartColorTheme.overestimated)
                                .padding(.top, 2)
                        }
                        
                        Button(action: {
                            checkCredentials()
                        }) {
                            Text("Увійти як Адмін")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
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



