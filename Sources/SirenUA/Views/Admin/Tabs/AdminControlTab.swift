import SwiftUI

struct AdminControlTab: View {
    @ObservedObject var viewModel: AdminViewModel
    @State private var showingRestartConfirmation = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Success Toast notification
            if viewModel.showSimSuccessMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ChartColorTheme.confirmed)
                    Text(viewModel.simSuccessText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(12)
                .background(ChartColorTheme.confirmed.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ChartColorTheme.confirmed.opacity(0.5), lineWidth: 1)
                )
                .cornerRadius(10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 1. Server Configuration & Deployment Card
            serverConfigCard
            
            // 2. Tactical Scenarios Grid (Integrated from former Settings)
            tacticalScenariosCard
            
            // 3. Advanced Threat Crafter Form
            threatCrafterCard
            
            // 4. AI & System Maintenance Operations
            aiMaintenanceCard
            
            // 5. Connection Diagnostics Panel
            diagnosticsCard
        }
        .padding(.top, 4)
        .onAppear {
            if viewModel.regionsList.isEmpty {
                Task { await viewModel.loadRegions() }
            }
            if viewModel.customServerURLSetting.isEmpty {
                viewModel.customServerURLSetting = NetworkManager.serverURL
            }
        }
        .confirmationDialog("Перезавантажити сервер?", isPresented: $showingRestartConfirmation, titleVisibility: .visible) {
            Button("Перезавантажити зараз", role: .destructive) {
                Task { await viewModel.restartServer() }
            }
            Button("Скасувати", role: .cancel) {}
        } message: {
            Text("Сервер виконає плавне перезавантаження (процес оновиться за 2-3 секунди).")
        }
    }

    // MARK: - 1. Server & Deployment Card
    private var serverConfigCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(ChartColorTheme.cyan)
                Text("Сервер та Деплоймент")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                
                // Active latency pill
                if let latency = viewModel.serverLatencyMs {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(ChartColorTheme.confirmed)
                            .frame(width: 6, height: 6)
                        Text("\(latency) ms")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(ChartColorTheme.confirmed)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ChartColorTheme.confirmed.opacity(0.15))
                    .cornerRadius(6)
                }
            }

            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Цільова URL-адреса backend:")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    
                    HStack(spacing: 8) {
                        TextField("http://...", text: $viewModel.customServerURLSetting)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button(action: {
                            viewModel.setServerURL(viewModel.customServerURLSetting)
                        }) {
                            Text("Зберегти")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                }

                // Quick presets
                VStack(alignment: .leading, spacing: 6) {
                    Text("Швидкі пресети підключення:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            viewModel.customServerURLSetting = "http://127.0.0.1:8085"
                            viewModel.setServerURL("http://127.0.0.1:8085")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "laptopcomputer")
                                Text("Локальний (:8085)")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                        }

                        Button(action: {
                            viewModel.customServerURLSetting = "https://e7d9-185-94-219-55.ngrok-free.app"
                            viewModel.setServerURL("https://e7d9-185-94-219-55.ngrok-free.app")
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.swap")
                                Text("Ngrok тунель")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                        }
                        
                        Button(action: {
                            viewModel.customServerURLSetting = ""
                            viewModel.setServerURL("")
                        }) {
                            Text("Скинути")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(6)
                        }
                    }
                }
                
                Divider().background(Color.white.opacity(0.08)).padding(.vertical, 2)
                
                // Server Restart Button
                Button(action: {
                    showingRestartConfirmation = true
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isRestartingServer {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                            Text("Перезавантаження сервера...")
                        } else {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Перезавантажити сервер (Restart)")
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                }
                .disabled(viewModel.isRestartingServer)
            }
        }
        .padding(14)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(12)
    }

    // MARK: - 2. Tactical Scenarios Grid Card
    private var tacticalScenariosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.badge.automatic.fill")
                    .foregroundColor(ChartColorTheme.orange)
                Text("Симуляція бойових сценаріїв")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("Preset Triggers")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            Text("Миттєва генерація тактичних загроз для тестування відгуку карти, push-сповіщень та ланцюжків Маркова.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
                .lineSpacing(3)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    scenarioButton(
                        title: "Шахеди з півдня",
                        icon: "paperplane.circle.fill",
                        scenarioId: "shaheds_south",
                        color: ChartColorTheme.orange
                    )
                    
                    scenarioButton(
                        title: "Зліт МіГ-31К",
                        icon: "airplane",
                        scenarioId: "mig_takeoff",
                        color: ChartColorTheme.overestimated
                    )
                }

                HStack(spacing: 8) {
                    scenarioButton(
                        title: "Ракети (Захід)",
                        icon: "location.north.line.fill",
                        scenarioId: "cruise_missiles_west",
                        color: ChartColorTheme.accent
                    )
                    
                    scenarioButton(
                        title: "Балістика (Харків)",
                        icon: "exclamationmark.triangle.fill",
                        scenarioId: "ballistic_kharkiv",
                        color: ChartColorTheme.purple
                    )
                }

                HStack(spacing: 8) {
                    scenarioButton(
                        title: "Масований наліт",
                        icon: "burst.fill",
                        scenarioId: "massive_attack",
                        color: Color.red
                    )
                    
                    Button(action: {
                        Task { await viewModel.postClearAll() }
                    }) {
                        HStack(spacing: 6) {
                            if viewModel.isClearingThreats {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.white)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                            }
                            Text("Очистити все")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                        )
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.isClearingThreats)
                }
            }
        }
        .padding(14)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func scenarioButton(title: String, icon: String, scenarioId: String, color: Color) -> some View {
        let isRunning = viewModel.isTriggeringScenario == scenarioId
        Button(action: {
            Task { await viewModel.postTriggerScenario(scenarioId) }
        }) {
            HStack(spacing: 6) {
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Image(systemName: icon)
                        .foregroundColor(color)
                }
                Text(title)
                    .lineLimit(1)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .disabled(viewModel.isTriggeringScenario != nil)
    }

    // MARK: - 3. Threat Crafter Card
    private var threatCrafterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(ChartColorTheme.cyan)
                Text("Ручний інжектор загроз")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("Custom Injector")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            VStack(spacing: 10) {
                // Region picker
                HStack {
                    Text("Область:")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Picker("", selection: $viewModel.simRegion) {
                        ForEach(viewModel.regionsList.isEmpty ? ["Київська область", "Сумська область", "Харківська область", "Полтавська область", "Одеська область", "Дніпропетровська область", "Львівська область"] : viewModel.regionsList, id: \.self) { r in
                            Text(r).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
                
                // Threat Level picker
                HStack {
                    Text("Рівень небезпеки:")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Picker("", selection: $viewModel.simLevel) {
                        Text("🟢 Відбій (none)").tag("none")
                        Text("🟡 Жовтий (low)").tag("low")
                        Text("🟠 Помаранчевий (medium)").tag("medium")
                        Text("🔴 Червоний (high)").tag("high")
                        Text("🟣 Бордовий (critical)").tag("critical")
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
                
                // Threat Type picker
                HStack {
                    Text("Тип загрози:")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Picker("", selection: $viewModel.simThreatType) {
                        Text("Шахед (shahed)").tag("shahed")
                        Text("МіГ-31К (mig31k)").tag("mig31k")
                        Text("Крилаті ракети (cruise_missile)").tag("cruise_missile")
                        Text("Балістика (ballistic)").tag("ballistic")
                        Text("КАБ (kab)").tag("kab")
                        Text("Артилерія (artillery)").tag("artillery")
                        Text("Розвід. БПЛА (recon)").tag("recon")
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
                
                // Confidence Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Впевненість ШІ / Джерела:")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("\(Int(viewModel.simConfidence))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(ChartColorTheme.cyan)
                    }
                    Slider(value: $viewModel.simConfidence, in: 20...100, step: 5)
                        .tint(ChartColorTheme.cyan)
                }
                .padding(8)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
                
                // Detail description
                VStack(alignment: .leading, spacing: 4) {
                    Text("Детальний опис загрози:")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                    TextField("Наприклад: 2 БПЛА курсом на місто...", text: $viewModel.simDetail)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                }

                // Expandable Telemetry
                DisclosureGroup(
                    isExpanded: $viewModel.isAdvancedTelemetryExpanded,
                    content: {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Швидкість (км/год):")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.5))
                                    TextField("185", text: $viewModel.simSpeedKmh)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(6)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Курс (градуси °):")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.5))
                                    TextField("280", text: $viewModel.simHeadingDegrees)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(6)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Вектор підльоту (Attack Vector):")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                                TextField("south_to_north", text: $viewModel.simAttackVector)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.top, 6)
                    },
                    label: {
                        HStack {
                            Image(systemName: "location.north.circle.fill")
                                .foregroundColor(.cyan)
                                .font(.system(size: 11))
                            Text("Тактична телеметрія (опціонально)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                )
                .padding(8)
                .background(Color.white.opacity(0.02))
                .cornerRadius(8)
                
                // Submit Button
                Button(action: {
                    viewModel.triggerHaptic("heavy")
                    Task { await viewModel.injectCustomThreat() }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                        Text("Надіслати загрозу в систему")
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
        .padding(14)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(12)
    }

    // MARK: - 4. AI & Maintenance Card
    private var aiMaintenanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(ChartColorTheme.purple)
                Text("Автономні процеси та самонавчання")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 8) {
                // Post-Mortem Trigger Button
                Button(action: {
                    Task { await viewModel.triggerPostMortem(hours: 4) }
                }) {
                    HStack {
                        if viewModel.isTriggeringPostMortem {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("Запустити Post-Mortem рефлексію")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ChartColorTheme.purple.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ChartColorTheme.purple.opacity(0.5), lineWidth: 1)
                    )
                    .cornerRadius(8)
                }
                .disabled(viewModel.isTriggeringPostMortem)
                
                // 6h Rules Learner Trigger Button
                Button(action: {
                    Task { await viewModel.triggerLearner() }
                }) {
                    HStack {
                        if viewModel.isTriggeringLearner {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                        }
                        Text("Запустити 6-годинний Rules Learner")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ChartColorTheme.cyan.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ChartColorTheme.cyan.opacity(0.4), lineWidth: 1)
                    )
                    .cornerRadius(8)
                }
                .disabled(viewModel.isTriggeringLearner)
                
                // Seed Demo History Button
                Button(action: {
                    Task { await viewModel.seedHistory() }
                }) {
                    HStack {
                        Image(systemName: "tray.and.arrow.down.fill")
                        Text("Заповнити систему демо-історією (Seed)")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(12)
    }

    // MARK: - 5. Diagnostics Card
    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gauge.with.needle.fill")
                    .foregroundColor(ChartColorTheme.accent)
                Text("Діагностика з'єднання та вузлів")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    viewModel.triggerHaptic("light")
                    Task { await viewModel.performDiagnostics() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ChartColorTheme.cyan)
                }
            }
            
            VStack(spacing: 8) {
                adminStatusRow(name: "Офіційні тривоги (ubilling API)", status: viewModel.alertsStatus)
                adminStatusRow(name: "Бекенд загроз (SirenUA Backend)", status: viewModel.threatsStatus)
                adminStatusRow(name: "Аналізатор ШІ (Gemini 2.5 Flash)", status: viewModel.geminiStatus)
            }
        }
        .padding(14)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func adminStatusRow(name: String, status: String) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor(status))
                    .frame(width: 8, height: 8)
                Text(status)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(statusColor(status))
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(6)
    }

    private func statusColor(_ status: String) -> Color {
        let upper = status.uppercased()
        if upper.contains("ONLINE") || upper.contains("АКТИВНИЙ") || upper.contains("OK") {
            return ChartColorTheme.confirmed
        }
        if upper.contains("CHECKING") || upper.contains("MOCK") {
            return ChartColorTheme.active
        }
        return ChartColorTheme.overestimated
    }
}

