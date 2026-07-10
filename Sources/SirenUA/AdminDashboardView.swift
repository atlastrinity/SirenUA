import SwiftUI
import Charts
import SafariServices

// MARK: - Decodable API Models (v2)

struct AdminErrorEntry: Codable, Identifiable {
    let id: Int
    let timestamp: String
    let source: String
    let error_type: String
    let message: String
    let endpoint: String?
    let context: String?
}

struct AdminErrorsResponse: Codable {
    let total: Int
    let errors: [AdminErrorEntry]
}

struct SourceStat: Codable, Identifiable {
    let id = UUID()
    let source: String
    let count: Int
    enum CodingKeys: String, CodingKey {
        case source, count
    }
}

struct TypeStat: Codable, Identifiable {
    let id = UUID()
    let error_type: String
    let count: Int
    enum CodingKeys: String, CodingKey {
        case error_type = "error_type"
        case count
    }
}

struct HourlyStat: Codable, Identifiable {
    let id = UUID()
    let hour: String
    let count: Int
    enum CodingKeys: String, CodingKey {
        case hour, count
    }
}

struct AdminErrorStatsResponse: Codable {
    let total: Int
    let by_source: [SourceStat]
    let by_type: [TypeStat]
    let hourly: [HourlyStat]
}

struct AdminChronologyEntry: Codable, Identifiable {
    let id: Int
    let region: String
    let threat_level: String
    let threat_type: String
    let confidence_at_set: Int?
    let confidence_at_clear: Int?
    let was_predictive: Int
    let prediction_accuracy: String?
    let lifecycle_status: String
    let duration_seconds: Int?
    let gemini_group_id: String?
    let threat_timestamp: String?
    let threat_detail: String?
    let clearing_timestamp: String?
    let resolution_type: String?
    let match_type: String // match, mismatch, active, cleared
}

struct DailyStatEntry: Codable, Identifiable {
    let id = UUID()
    let day: String
    let total_events: Int
    let cleared: Int
    let active: Int?
    let confirmed: Int
    let overestimated: Int
    let mitigated: Int?
    let predictive: Int
    enum CodingKeys: String, CodingKey {
        case day, total_events, cleared, active, confirmed, overestimated, mitigated, predictive
    }
}

struct AdminChronologyResponse: Codable {
    let total: Int
    let events: [AdminChronologyEntry]
    let daily_stats: [DailyStatEntry]
}

struct GeminiRule: Codable, Identifiable {
    let id: Int
    let created_at: String
    let updated_at: String
    let rule_type: String
    let source_region: String?
    let target_region: String?
    let threat_type: String?
    let rule_text: String
    let evidence_count: Int
    let accuracy_score: Double
    let is_active: Int
}

struct GeminiRulesResponse: Codable {
    let total: Int
    let rules: [GeminiRule]
}

struct GeminiRuleAuditEntry: Codable, Identifiable {
    let id: Int
    let timestamp: String
    let action: String
    let rule_type: String?
    let rule_text: String?
    let source_region: String?
    let target_region: String?
    let threat_type: String?
    let reason: String?
}

struct GeminiRulesHistoryResponse: Codable {
    let total: Int
    let entries: [GeminiRuleAuditEntry]
}

// MARK: - Redesigned Dashboard v2 Decodables

struct DashboardAccuracyStats: Codable {
    let confirmed: Int?
    let mitigated: Int?
    let overestimated: Int?
    let active: Int?
    let total: Int?
}

struct DashboardThreatTypeStat: Codable, Identifiable {
    let id = UUID()
    let threat_type: String
    let count: Int
    enum CodingKeys: String, CodingKey {
        case threat_type, count
    }
}

struct DashboardRegionStat: Codable, Identifiable {
    let id = UUID()
    let region: String
    let count: Int
    enum CodingKeys: String, CodingKey {
        case region, count
    }
}

struct DashboardHourlyStat: Codable, Identifiable {
    let id = UUID()
    let hour: Int
    let count: Int
    enum CodingKeys: String, CodingKey {
        case hour, count
    }
}

struct AdminDashboardStatsResponse: Codable {
    let total_events_7d: Int
    let accuracy: DashboardAccuracyStats
    let accuracy_pct: Double
    let active_now: Int
    let avg_early_seconds: Int?
    let by_type: [DashboardThreatTypeStat]
    let top_regions: [DashboardRegionStat]
    let hourly: [DashboardHourlyStat]
    let errors_24h: Int
}

// MARK: - Redesigned Correlation v2 Decodables

struct AdminChronologyV2Entry: Codable, Identifiable {
    let id: Int
    let region: String
    let threat_level: String
    let threat_type: String
    let confidence_at_set: Int?
    let confidence_at_clear: Int?
    let was_predictive: Int
    let prediction_accuracy: String?
    let lifecycle_status: String
    let duration_seconds: Int?
    let gemini_group_id: String?
    let ai_timestamp: String?
    let threat_detail: String?
    let attack_vector: String?
    let target_count: Int?
    let speed_kmh: Int?
    let weapon_subtype: String?
    let launch_origin: String?
    let altitude_category: String?
    let distance_to_target_km: Double?
    let event_phase: String?
    let source_reliability: String?
    let civilian_risk_level: String?
    let clearing_timestamp: String?
    let resolution_type: String?
    let alarm_timestamp: String?
    let time_delta_seconds: Int?
    let match_type: String // confirmed, mitigated, overestimated, active, cleared
    let match_reason: String?
    let telemetry_summary: String?
}

struct DailyStatEntryV2: Codable, Identifiable {
    let id = UUID()
    let day: String
    let total_events: Int
    let cleared: Int
    let confirmed: Int
    let overestimated: Int
    let mitigated: Int
    let predictive: Int
    enum CodingKeys: String, CodingKey {
        case day, total_events, cleared, confirmed, overestimated, mitigated, predictive
    }
}

struct TypeBreakdownEntry: Codable, Identifiable {
    let id = UUID()
    let threat_type: String
    let prediction_accuracy: String?
    let count: Int
    enum CodingKeys: String, CodingKey {
        case threat_type, prediction_accuracy, count
    }
}

struct DeltaDistributionBucket: Identifiable {
    let id: String
    let label: String
    let minutes: Int
    let count: Int
}

struct AdminChronologyV2Response: Codable {
    let total: Int
    let stats: [String: Int]
    let events: [AdminChronologyV2Entry]
    let daily_stats: [DailyStatEntryV2]
    let delta_distribution: [String: Int]
    let type_breakdown: [TypeBreakdownEntry]
}

// MARK: - UI Constants

struct ChartColorTheme {
    static let confirmed = Color(red: 0.29, green: 0.87, blue: 0.50) // #4ade80
    static let mitigated = Color(red: 0.65, green: 0.54, blue: 0.98) // #a78bfa
    static let overestimated = Color(red: 1.00, green: 0.36, blue: 0.36) // #ff5c5c
    static let active = Color(red: 0.98, green: 0.75, blue: 0.14) // #fbbf24
    static let cleared = Color(red: 0.35, green: 0.43, blue: 0.53) // #5a6e87
    static let accent = Color(red: 0.31, green: 0.62, blue: 1.00) // #4f9eff
    static let cyan = Color(red: 0.13, green: 0.83, blue: 0.93) // #22d3ee
    static let orange = Color(red: 0.98, green: 0.57, blue: 0.24) // #fb923c
    static let bg = Color(red: 0.04, green: 0.05, blue: 0.08)
    static let cardBg = Color(red: 0.07, green: 0.10, blue: 0.13)
}

// MARK: - AdminDashboardView

struct AdminDashboardView: View {
    @Environment(\.dismiss) var dismiss
    
    // Custom Horizontal Scrollable Navigation Tabs
    @State private var selectedTab = 0
    private let tabs = [
        "Дашборд",
        "Кореляція AI",
        "Хронологія",
        "AI Правила",
        "Помилки",
        "Керування"
    ]
    
    // Server status pings
    @State private var alertsStatus: String = "Перевірка..."
    @State private var threatsStatus: String = "Перевірка..."
    @State private var geminiStatus: String = "Перевірка..."
    
    // Filters
    @State private var daysFilter = 7
    @State private var rulesDaysFilter = 30
    
    // Chronology Filters
    @State private var chrRegionFilter = ""
    @State private var chrThreatTypeFilter = ""
    @State private var chrMatchFilter = ""
    
    // AI Rules Filters
    @State private var rulesTypeFilter = ""
    @State private var rulesThreatTypeFilter = ""
    @State private var rulesActionFilter = ""
    
    // Correlation Filters
    @State private var corDaysFilter = 7
    @State private var corRegionFilter = ""
    @State private var corThreatTypeFilter = ""
    @State private var corMatchFilter = ""
    @State private var corUseDateRange = false
    @State private var corDateFrom = Date().addingTimeInterval(-7*86400)
    @State private var corDateTo = Date()
    
    // Errors Filters
    @State private var errDaysFilter = 7
    @State private var errSourceFilter = ""
    @State private var errTypeFilter = ""
    
    // Manual Threat Simulation Form
    @State private var simRegion = "Київська область"
    @State private var simLevel = "high"
    @State private var simThreatType = "shahed"
    @State private var simDetail = "Група ударних БПЛА рухається курсом на Васильків"
    @State private var showSimSuccessMessage = false
    @State private var simSuccessText = ""
    
    // Data Loading states
    @State private var isLoading = false
    @State private var showRebuildSuccess = false
    
    // Tab Data Stores
    @State private var dashboardStats: AdminDashboardStatsResponse? = nil
    @State private var correlationV2Data: AdminChronologyV2Response? = nil
    @State private var chronologyData: AdminChronologyResponse? = nil
    @State private var activeRules: [GeminiRule] = []
    @State private var ruleAuditHistory: [GeminiRuleAuditEntry] = []
    @State private var errorsList: [AdminErrorEntry] = []
    @State private var errorStats: AdminErrorStatsResponse? = nil
    
    @State private var regionsList: [String] = []
    
    private let serverURL = "https://sirenua-threatserver.onrender.com"

    var body: some View {
        NavigationView {
            ZStack {
                ChartColorTheme.bg.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerView
                    tabSelectorView
                    Divider().background(Color.white.opacity(0.1))
                    
                    if isLoading {
                        Spacer()
                        ProgressView("Завантаження даних...")
                            .tint(.white)
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                switch selectedTab {
                                case 0:
                                    dashboardTabContent
                                case 1:
                                    correlationTabContent
                                case 2:
                                    chronologyTabContent
                                case 3:
                                    rulesTabContent
                                case 4:
                                    errorsTabContent
                                default:
                                    controlTabContent
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                            .padding(.bottom, 32)
                        }
                        .refreshable {
                            await refreshCurrentTab()
                        }
                    }
                }
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #else
            .navigationTitle("")
            #endif
            .preferredColorScheme(.dark)
            .task {
                await loadRegions()
                await refreshAllData()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("🚨 SirenUA Console")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .shadow(color: .green, radius: 4)
                    Text("Нативний iOS моніторинг")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
            Button(action: {
                triggerHaptic()
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ChartColorTheme.cardBg)
    }
    
    // MARK: - Tab Selector Bar
    
    private var tabSelectorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<tabs.count, id: \.self) { idx in
                    Button(action: {
                        triggerHaptic("light")
                        selectedTab = idx
                        Task { await refreshCurrentTab() }
                    }) {
                        Text(tabs[idx])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selectedTab == idx ? .white : .white.opacity(0.55))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedTab == idx ? Color.blue.opacity(0.3) : Color.white.opacity(0.04)
                            )
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(selectedTab == idx ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(ChartColorTheme.bg)
    }
    
    // MARK: - Tab 0: Dashboard (Дашборд)
    
    private var dashboardTabContent: some View {
        VStack(spacing: 14) {
            if let d = dashboardStats {
                // Stat grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statBox(title: "📈 Подій (7д)", value: "\(d.total_events_7d)", color: ChartColorTheme.accent)
                    statBox(title: "🎯 Точність AI", value: "\(Int(d.accuracy_pct))%", color: ChartColorTheme.confirmed)
                    statBox(title: "⚡ Активних зараз", value: "\(d.active_now)", color: ChartColorTheme.active)
                    statBox(title: "⏱️ Випередження AI", value: d.avg_early_seconds != nil ? formatDuration(d.avg_early_seconds!) : "—", color: ChartColorTheme.cyan)
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statBox(title: "✅ Підтверджено", value: "\(d.accuracy.confirmed ?? 0)", color: ChartColorTheme.confirmed)
                    statBox(title: "🛡️ Збито/РЕБ", value: "\(d.accuracy.mitigated ?? 0)", color: ChartColorTheme.mitigated)
                    statBox(title: "❌ Помилкові", value: "\(d.accuracy.overestimated ?? 0)", color: ChartColorTheme.overestimated)
                    statBox(title: "🔴 Помилки (24г)", value: "\(d.errors_24h)", color: ChartColorTheme.orange)
                }
                
                // Accuracy sector map
                VStack(alignment: .leading, spacing: 12) {
                    Text("🎯 Результати аналізу AI")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Chart {
                        SectorMark(angle: .value("Count", d.accuracy.confirmed ?? 0), innerRadius: .ratio(0.6), angularInset: 1.5)
                            .foregroundStyle(ChartColorTheme.confirmed)
                            .annotation(position: .overlay) {
                                Text("\(d.accuracy.confirmed ?? 0)").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            }
                        SectorMark(angle: .value("Count", d.accuracy.mitigated ?? 0), innerRadius: .ratio(0.6), angularInset: 1.5)
                            .foregroundStyle(ChartColorTheme.mitigated)
                            .annotation(position: .overlay) {
                                Text("\(d.accuracy.mitigated ?? 0)").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            }
                        SectorMark(angle: .value("Count", d.accuracy.overestimated ?? 0), innerRadius: .ratio(0.6), angularInset: 1.5)
                            .foregroundStyle(ChartColorTheme.overestimated)
                            .annotation(position: .overlay) {
                                Text("\(d.accuracy.overestimated ?? 0)").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                            }
                        SectorMark(angle: .value("Count", d.accuracy.active ?? 0), innerRadius: .ratio(0.6), angularInset: 1.5)
                            .foregroundStyle(ChartColorTheme.active)
                    }
                    .frame(height: 140)
                    
                    HStack(spacing: 12) {
                        legendItem(title: "Підтв.", color: ChartColorTheme.confirmed)
                        legendItem(title: "Збито", color: ChartColorTheme.mitigated)
                        legendItem(title: "Помилк.", color: ChartColorTheme.overestimated)
                        legendItem(title: "Актив.", color: ChartColorTheme.active)
                    }
                    .font(.system(size: 11))
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(14)
                .background(ChartColorTheme.cardBg)
                .cornerRadius(14)
                
                // Threat types bar chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("🚀 Загрози за типами (7д)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Chart {
                        ForEach(d.by_type) { item in
                            BarMark(
                                x: .value("Кількість", item.count),
                                y: .value("Тип", item.threat_type)
                            )
                            .foregroundStyle(ChartColorTheme.accent)
                            .cornerRadius(4)
                        }
                    }
                    .frame(height: CGFloat(max(80, d.by_type.count * 25)))
                }
                .padding(14)
                .background(ChartColorTheme.cardBg)
                .cornerRadius(14)

                // Top regions
                VStack(alignment: .leading, spacing: 12) {
                    Text("🗺️ Топ регіонів за загрозами")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Chart {
                        ForEach(d.top_regions) { item in
                            BarMark(
                                x: .value("Кількість", item.count),
                                y: .value("Область", String(item.region.prefix(12)))
                            )
                            .foregroundStyle(ChartColorTheme.cyan)
                            .cornerRadius(4)
                        }
                    }
                    .frame(height: 180)
                }
                .padding(14)
                .background(ChartColorTheme.cardBg)
                .cornerRadius(14)

                // Hourly timeline
                VStack(alignment: .leading, spacing: 12) {
                    Text("🕐 Розподіл загроз за годинами доби")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Chart {
                        ForEach(d.hourly) { item in
                            AreaMark(
                                x: .value("Година", item.hour),
                                y: .value("Кількість", item.count)
                            )
                            .foregroundStyle(ChartColorTheme.accent.opacity(0.15))
                            .interpolationMethod(.catmullRom)
                            
                            LineMark(
                                x: .value("Година", item.hour),
                                y: .value("Кількість", item.count)
                            )
                            .foregroundStyle(ChartColorTheme.accent)
                            .interpolationMethod(.catmullRom)
                            .symbol(Circle())
                        }
                    }
                    .frame(height: 140)
                    .chartXScale(domain: 0...23)
                }
                .padding(14)
                .background(ChartColorTheme.cardBg)
                .cornerRadius(14)
            } else {
                Text("Не вдалося завантажити статистику.")
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 40)
            }
        }
    }
    
    // MARK: - Tab 1: Correlation AI (Кореляція)
    
    private var correlationTabContent: some View {
        VStack(spacing: 14) {
            // Advanced Filters Accordion/Panel
            VStack(spacing: 10) {
                HStack {
                    Text("Фільтрація подій")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Toggle("Діапазон дат", isOn: $corUseDateRange)
                        .labelsHidden()
                        .tint(.blue)
                }
                
                if corUseDateRange {
                    DatePicker("Від:", selection: $corDateFrom, displayedComponents: .date)
                        .font(.system(size: 12))
                    DatePicker("До:", selection: $corDateTo, displayedComponents: .date)
                        .font(.system(size: 12))
                } else {
                    HStack {
                        Text("Період:")
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: $corDaysFilter) {
                            Text("1 день").tag(1)
                            Text("3 дні").tag(3)
                            Text("7 днів").tag(7)
                            Text("14 днів").tag(14)
                            Text("30 днів").tag(30)
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                HStack(spacing: 8) {
                    Picker("Регіон", selection: $corRegionFilter) {
                        Text("Всі області").tag("")
                        ForEach(regionsList, id: \.self) { r in
                            Text(r).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    Picker("Загроза", selection: $corThreatTypeFilter) {
                        Text("Всі типи").tag("")
                        Text("Shahed").tag("shahed")
                        Text("МіГ-31К").tag("mig31k")
                        Text("Крилаті ракети").tag("cruise_missile")
                        Text("Балістика").tag("ballistic")
                        Text("Обстріл").tag("artillery")
                        Text("БПЛА").tag("recon")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }
                
                HStack {
                    Picker("Результат", selection: $corMatchFilter) {
                        Text("Всі результати").tag("")
                        Text("✅ Підтверджено").tag("match")
                        Text("🛡️ Збито/РЕБ").tag("mitigated")
                        Text("❌ Помилкові").tag("mismatch")
                        Text("⏱️ Активні").tag("active")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Button(action: {
                        Task { await fetchCorrelationV2() }
                    }) {
                        Text("Оновити фільтр")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(12)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)
            
            if let corr = correlationV2Data {
                // Dynamic stats counters
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    statBox(title: "Всього", value: "\(corr.total)", color: .white)
                    statBox(title: "✅ Підтверджено", value: "\(corr.stats["confirmed"] ?? 0)", color: ChartColorTheme.confirmed)
                    statBox(title: "🛡️ Збито", value: "\(corr.stats["mitigated"] ?? 0)", color: ChartColorTheme.mitigated)
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    statBox(title: "❌ Помилкові", value: "\(corr.stats["overestimated"] ?? 0)", color: ChartColorTheme.overestimated)
                    statBox(title: "⏱️ Активні", value: "\(corr.stats["active"] ?? 0)", color: ChartColorTheme.active)
                }

                // Chart: Stacked Bar Chart daily accuracy
                VStack(alignment: .leading, spacing: 12) {
                    Text("📊 Динаміка аналізу AI за днями")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Chart {
                        ForEach(corr.daily_stats) { item in
                            BarMark(
                                x: .value("Day", formatShortDate(item.day)),
                                y: .value("Confirmed", item.confirmed)
                            )
                            .foregroundStyle(ChartColorTheme.confirmed)
                            
                            BarMark(
                                x: .value("Day", formatShortDate(item.day)),
                                y: .value("Mitigated", item.mitigated)
                            )
                            .foregroundStyle(ChartColorTheme.mitigated)
                            
                            BarMark(
                                x: .value("Day", formatShortDate(item.day)),
                                y: .value("False", item.overestimated)
                            )
                            .foregroundStyle(ChartColorTheme.overestimated)
                        }
                    }
                    .frame(height: 150)
                }
                .padding(14)
                .background(ChartColorTheme.cardBg)
                .cornerRadius(14)
                
                // Chart: Delta Distribution Histogram
                let buckets = getSortedBuckets(corr.delta_distribution)
                if !buckets.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("⏱️ Часове випередження AI до тривоги")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Chart {
                            ForEach(buckets) { item in
                                BarMark(
                                    x: .value("Час", item.label),
                                    y: .value("Кількість", item.count)
                                )
                                .foregroundStyle(item.minutes >= 0 ? ChartColorTheme.confirmed : ChartColorTheme.overestimated)
                                .cornerRadius(4)
                            }
                        }
                        .frame(height: 130)
                    }
                    .padding(14)
                    .background(ChartColorTheme.cardBg)
                    .cornerRadius(14)
                }
                
                // Chart: Type breakdown
                if !corr.type_breakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🚀 Результати ШІ по типу загрози")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Chart {
                            ForEach(corr.type_breakdown) { item in
                                BarMark(
                                    x: .value("Тип", item.threat_type),
                                    y: .value("Кількість", item.count)
                                )
                                .foregroundStyle(by: .value("Статус", formatAccuracyStatus(item.prediction_accuracy)))
                            }
                        }
                        .chartForegroundStyleScale([
                            "Підтверджено": ChartColorTheme.confirmed,
                            "Збито/РЕБ": ChartColorTheme.mitigated,
                            "Помилково": ChartColorTheme.overestimated,
                            "Інше": ChartColorTheme.cleared
                        ])
                        .frame(height: 150)
                    }
                    .padding(14)
                    .background(ChartColorTheme.cardBg)
                    .cornerRadius(14)
                }
                
                // Event cards list
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Детальна кореляція (\(corr.events.count))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    if groupedCorrelationEvents.isEmpty {
                        Text("Немає подій за вибраними фільтрами.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 30)
                    } else {
                        ForEach(groupedCorrelationEvents, id: \.0) { day, events in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("📅 \(day) (\(events.count) детекцій)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.top, 8)
                                    .padding(.bottom, 2)
                                
                                ForEach(events) { ev in
                                    VStack(alignment: .leading, spacing: 8) {
                                        // Title line
                                        HStack {
                                            Text(ev.match_type == "confirmed" ? "✅" :
                                                 ev.match_type == "mitigated" ? "🛡️" :
                                                 ev.match_type == "overestimated" ? "❌" :
                                                 ev.match_type == "active" ? "⏱️" : "🔄")
                                            
                                            Text(ev.region)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                            
                                            Spacer()
                                            
                                            Text(ev.threat_level)
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(
                                                    ev.threat_level == "high" ? Color.red.opacity(0.2) : Color.yellow.opacity(0.2)
                                                )
                                                .foregroundColor(
                                                    ev.threat_level == "high" ? Color.red : Color.yellow
                                                )
                                                .cornerRadius(4)
                                            
                                            if let conf = ev.confidence_at_set {
                                                Text("\(conf)%")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white.opacity(0.5))
                                            }
                                        }
                                        
                                        // Meta Grid
                                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                                            metaRow(label: "AI детекція:", value: ev.ai_timestamp != nil ? formatShortTime(ev.ai_timestamp!) : "—")
                                            metaRow(label: "Офіційна тривога:", value: ev.alarm_timestamp != nil ? formatShortTime(ev.alarm_timestamp!) : "—")
                                            
                                            if let delta = ev.time_delta_seconds {
                                                let sign = delta > 0 ? "+" : ""
                                                metaRow(label: "Δ Час:", value: "\(sign)\(formatDuration(delta))", color: delta >= 0 ? .green : .red)
                                            } else {
                                                metaRow(label: "Δ Час:", value: "—")
                                            }
                                            
                                            metaRow(label: "Тривалість:", value: ev.duration_seconds != nil ? formatDuration(ev.duration_seconds!) : "—")
                                        }
                                        .font(.system(size: 11))
                                        
                                        // Match reason box
                                        if let reason = ev.match_reason {
                                            Text(reason)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(
                                                    ev.match_type == "confirmed" ? ChartColorTheme.confirmed :
                                                    ev.match_type == "mitigated" ? ChartColorTheme.mitigated :
                                                    ev.match_type == "overestimated" ? ChartColorTheme.overestimated :
                                                    ev.match_type == "active" ? ChartColorTheme.active : .white.opacity(0.5)
                                                )
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.white.opacity(0.03))
                                                .cornerRadius(6)
                                        }
                                        
                                        // Telemetry Summary tags
                                        if let telem = ev.telemetry_summary, !telem.isEmpty {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 6) {
                                                    ForEach(telem.components(separatedBy: " | "), id: \.self) { tag in
                                                        Text(tag)
                                                            .font(.system(size: 9, weight: .bold))
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2.5)
                                                            .background(Color.cyan.opacity(0.12))
                                                            .foregroundColor(ChartColorTheme.cyan)
                                                            .cornerRadius(4)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.02))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .background(ChartColorTheme.cardBg)
                .cornerRadius(14)
            }
        }
    }
    
    private func metaRow(label: String, value: String, color: Color = .white.opacity(0.6)) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundColor(.white.opacity(0.35))
            Text(value)
                .foregroundColor(color)
                .fontWeight(.medium)
            Spacer()
        }
    }
    
    private func getSortedBuckets(_ dict: [String: Int]) -> [DeltaDistributionBucket] {
        var items: [DeltaDistributionBucket] = []
        for (k, v) in dict {
            let minStr = k.replacingOccurrences(of: " хв", with: "").trimmingCharacters(in: .whitespaces)
            let mins = Int(minStr) ?? 0
            items.append(DeltaDistributionBucket(id: k, label: k, minutes: mins, count: v))
        }
        return items.sorted(by: { $0.minutes < $1.minutes })
    }

    private func formatAccuracyStatus(_ status: String?) -> String {
        switch status {
        case "confirmed": return "Підтверджено"
        case "mitigated": return "Збито/РЕБ"
        case "overestimated": return "Помилково"
        default: return "Інше"
        }
    }

    private var groupedCorrelationEvents: [(String, [AdminChronologyV2Entry])] {
        guard let events = correlationV2Data?.events else { return [] }
        let grouped = Dictionary(grouping: events) { ev in
            if let ts = ev.ai_timestamp, ts.count >= 10 {
                return String(ts.prefix(10))
            }
            return "Невідома дата"
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private var groupedChronologyEvents: [(String, [AdminChronologyEntry])] {
        guard let events = chronologyData?.events else { return [] }
        let grouped = Dictionary(grouping: events) { ev in
            if let ts = ev.threat_timestamp, ts.count >= 10 {
                return String(ts.prefix(10))
            }
            return "Невідома дата"
        }
        return grouped.sorted { $0.key > $1.key }
    }

    // MARK: - Tab 2: Chronology (legacy)
    
    private var chronologyTabContent: some View {
        VStack(spacing: 16) {
            // Filters Panel
            VStack(spacing: 10) {
                HStack {
                    Text("Фільтрація хронології")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                HStack {
                    Text("Період:")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $daysFilter) {
                        Text("1 день").tag(1)
                        Text("3 дні").tag(3)
                        Text("7 днів").tag(7)
                        Text("14 днів").tag(14)
                        Text("30 днів").tag(30)
                    }
                    .pickerStyle(.menu)
                }
                
                HStack(spacing: 8) {
                    Picker("Регіон", selection: $chrRegionFilter) {
                        Text("Всі області").tag("")
                        ForEach(regionsList, id: \.self) { r in
                            Text(r).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    Picker("Загроза", selection: $chrThreatTypeFilter) {
                        Text("Всі типи").tag("")
                        Text("Shahed").tag("shahed")
                        Text("МіГ-31К").tag("mig31k")
                        Text("Крилаті ракети").tag("cruise_missile")
                        Text("Балістика").tag("ballistic")
                        Text("КАБ").tag("kab")
                        Text("Артилерія").tag("artillery")
                        Text("БПЛА").tag("recon")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }
                
                HStack {
                    Picker("Результат", selection: $chrMatchFilter) {
                        Text("Всі результати").tag("")
                        Text("✅ Співпадіння").tag("match")
                        Text("🛡️ Збито/РЕБ").tag("mitigated")
                        Text("❌ Неспівпадіння").tag("mismatch")
                        Text("⏱️ Активні").tag("active")
                        Text("🔄 Зняті").tag("cleared")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Button(action: {
                        Task { await fetchChronology() }
                    }) {
                        Text("Оновити фільтр")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(12)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                statBox(title: "Всього подій", value: "\(chronologyData?.total ?? 0)", color: ChartColorTheme.accent)
                statBox(title: "✅ Співпадіння AI", value: "\(chronologyData?.events.filter({ $0.match_type == "match" }).count ?? 0)", color: ChartColorTheme.confirmed)
                statBox(title: "🛡️ Збито/РЕБ", value: "\(chronologyData?.events.filter({ $0.match_type == "mitigated" }).count ?? 0)", color: ChartColorTheme.mitigated)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                statBox(title: "❌ Неспівпадіння", value: "\(chronologyData?.events.filter({ $0.match_type == "mismatch" }).count ?? 0)", color: ChartColorTheme.overestimated)
                statBox(title: "⏱️ Активні", value: "\(chronologyData?.events.filter({ $0.match_type == "active" }).count ?? 0)", color: ChartColorTheme.active)
            }
            
            if let chrono = chronologyData {
                // Daily Chart for Total Alerts vs Cleared
                VStack(alignment: .leading, spacing: 12) {
                    Text("Загрози та відбої по днях")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Chart {
                        ForEach(chrono.daily_stats) { item in
                            BarMark(
                                x: .value("Day", formatShortDate(item.day)),
                                y: .value("Загрози", item.total_events)
                            )
                            .foregroundStyle(Color.red.opacity(0.8))
                            
                            BarMark(
                                x: .value("Day", formatShortDate(item.day)),
                                y: .value("Зняття", item.cleared)
                            )
                            .foregroundStyle(Color.green.opacity(0.8))
                        }
                    }
                    .frame(height: 140)
                }
                .padding(14)
                .background(ChartColorTheme.cardBg)
                .cornerRadius(12)
                
                // Accuracy Line Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Точність передбачень (%)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Chart {
                        ForEach(chrono.daily_stats) { item in
                            let confirmedCount = item.confirmed
                            let overestimatedCount = item.overestimated
                            let mitigatedCount = item.mitigated ?? 0
                            let total = confirmedCount + overestimatedCount + mitigatedCount
                            if total > 0 {
                                let accuracy = Double(confirmedCount) + Double(mitigatedCount) * 0.8
                                let accuracyPct = (accuracy / Double(total)) * 100.0
                                
                                AreaMark(
                                    x: .value("Day", formatShortDate(item.day)),
                                    y: .value("Точність", accuracyPct)
                                )
                                .foregroundStyle(ChartColorTheme.confirmed.opacity(0.1))
                                .interpolationMethod(.catmullRom)
                                
                                LineMark(
                                    x: .value("Day", formatShortDate(item.day)),
                                    y: .value("Точність", accuracyPct)
                                )
                                .foregroundStyle(ChartColorTheme.confirmed)
                                .interpolationMethod(.catmullRom)
                                .symbol(Circle())
                            }
                        }
                    }
                    .frame(height: 140)
                    .chartYScale(domain: 0...100)
                }
                .padding(14)
                .background(ChartColorTheme.cardBg)
                .cornerRadius(12)
                
                // Grouped Timeline list
                VStack(alignment: .leading, spacing: 12) {
                    Text("Стрічка подій хронології")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    if groupedChronologyEvents.isEmpty {
                        Text("Немає подій за вибраними фільтрами.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 30)
                    } else {
                        ForEach(groupedChronologyEvents, id: \.0) { day, events in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("📅 \(day) (\(events.count) подій)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.top, 8)
                                    .padding(.bottom, 2)
                                
                                  ForEach(events) { ev in
                                      HStack(alignment: .top, spacing: 8) {
                                          Text(ev.match_type == "match" ? "✅" :
                                               ev.match_type == "mitigated" ? "🛡️" :
                                               ev.match_type == "mismatch" ? "❌" :
                                               ev.match_type == "official" ? "🚨" :
                                               ev.match_type == "active" ? "⏱️" : "🔄")
                                          .font(.system(size: 16))
                                          
                                          VStack(alignment: .leading, spacing: 3) {
                                              HStack {
                                                  Text(ev.region)
                                                      .font(.system(size: 13, weight: .bold))
                                                      .foregroundColor(.white)
                                                  Spacer()
                                                  if let duration = ev.duration_seconds {
                                                      Text(formatDuration(duration))
                                                          .font(.system(size: 11))
                                                          .foregroundColor(.white.opacity(0.4))
                                                  }
                                              }
                                              
                                              Text(ev.threat_type == "official_alarm" ? "Офіційна тривога" : "\(ev.threat_type) (\(ev.threat_level))")
                                                  .font(.system(size: 11, weight: .medium))
                                                  .foregroundColor(ev.threat_type == "official_alarm" ? .red : .white.opacity(0.5))
                                              
                                              if let detail = ev.threat_detail {
                                                  Text(detail)
                                                      .font(.system(size: 12))
                                                      .foregroundColor(.white.opacity(0.8))
                                                      .lineLimit(2)
                                              }
                                              
                                              HStack {
                                                  if let tts = ev.threat_timestamp {
                                                      Text("Початок: \(formatShortTime(tts))")
                                                  }
                                                  if let cts = ev.clearing_timestamp {
                                                      Text(" · Відбій: \(formatShortTime(cts))")
                                                  }
                                              }
                                              .font(.system(size: 10))
                                              .foregroundColor(.white.opacity(0.35))
                                          }
                                      }
                                      .padding(10)
                                      .background(ev.match_type == "official" ? Color.red.opacity(0.08) : Color.white.opacity(0.01))
                                      .cornerRadius(8)
                                      .overlay(RoundedRectangle(cornerRadius: 8).stroke(ev.match_type == "official" ? Color.red.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1))
                                  }
                            }
                        }
                    }
                }
                .padding(14)
                .background(ChartColorTheme.cardBg)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Tab 3: AI Rules (Правила)
    
    private var rulesTabContent: some View {
        VStack(spacing: 16) {
            // Rules Filters Panel
            VStack(spacing: 10) {
                HStack {
                    Text("Фільтрація правил & аудиту")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                HStack {
                    Text("Днів аудиту:")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $rulesDaysFilter) {
                        Text("7 днів").tag(7)
                        Text("14 днів").tag(14)
                        Text("30 днів").tag(30)
                    }
                    .pickerStyle(.menu)
                }
                
                HStack(spacing: 8) {
                    Picker("Тип правила", selection: $rulesTypeFilter) {
                        Text("Всі типи").tag("")
                        Text("Маршрут").tag("route_pattern")
                        Text("Довіра").tag("confidence_correction")
                        Text("Часовий").tag("time_pattern")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    Picker("Загроза", selection: $rulesThreatTypeFilter) {
                        Text("Всі типи").tag("")
                        Text("Shahed").tag("shahed")
                        Text("МіГ-31К").tag("mig31k")
                        Text("Крилаті ракети").tag("cruise_missile")
                        Text("Балістика").tag("ballistic")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }
                
                HStack {
                    Picker("Дія аудиту", selection: $rulesActionFilter) {
                        Text("Всі дії").tag("")
                        Text("Створено").tag("added")
                        Text("Деактивовано").tag("deactivated")
                        Text("Видалено").tag("removed")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Button(action: {
                        Task { await fetchRules() }
                    }) {
                        Text("Оновити фільтр")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(12)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)
            
            // Rebuild rules section
            VStack(alignment: .leading, spacing: 12) {
                Text("🧠 Самонавчання ШІ (Gemini)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Запуск примусового аналізу paired_events для генерації нових правил або оновлення наявних.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .lineSpacing(3)
                
                Button(action: {
                    triggerHaptic()
                    Task { await rebuildRules() }
                }) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                        Text("Перебудувати правила навчання")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.purple.opacity(0.3))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.5), lineWidth: 1))
                }
                
                if showRebuildSuccess {
                    Text("✅ Правила успішно перебудовано на сервері!")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.top, 2)
                }
            }
            .padding(12)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)
            
            // Active rules list
            VStack(alignment: .leading, spacing: 10) {
                Text("Активні правила навчання (\(activeRules.count))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                if activeRules.isEmpty {
                    Text("Немає активних правил самонавчання.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(activeRules) { rule in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(rule.rule_type)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                                
                                Spacer()
                                
                                Text("\(Int(rule.accuracy_score * 100))% accuracy")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(rule.accuracy_score >= 0.7 ? .green : .yellow)
                                
                                Text("Evidences: \(rule.evidence_count)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            
                            Text(rule.rule_text)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(3)
                            
                            HStack(spacing: 8) {
                                if let src = rule.source_region, !src.isEmpty {
                                    let dst = rule.target_region ?? ""
                                    Text("🗺️ \(src) → \(dst)")
                                }
                                if let th = rule.threat_type, !th.isEmpty {
                                    Text("🚀 \(th)")
                                }
                                Spacer()
                                Text(formatShortTime(rule.updated_at))
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                }
            }
            .padding(14)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)
            
            // Rules history audit log
            VStack(alignment: .leading, spacing: 10) {
                Text("📜 Аудит-лог правил")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                if ruleAuditHistory.isEmpty {
                    Text("Аудит-лог правил порожній.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(ruleAuditHistory) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.action.uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        entry.action == "added" ? Color.green.opacity(0.2) :
                                        entry.action == "deactivated" ? Color.yellow.opacity(0.2) : Color.red.opacity(0.2)
                                    )
                                    .foregroundColor(
                                        entry.action == "added" ? Color.green :
                                        entry.action == "deactivated" ? Color.yellow : Color.red
                                    )
                                    .cornerRadius(4)
                                
                                Spacer()
                                
                                Text(formatShortTime(entry.timestamp))
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            
                            if let text = entry.rule_text, !text.isEmpty {
                                Text(text)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                            } else if let reason = entry.reason, !reason.isEmpty {
                                Text(reason)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            
                            HStack(spacing: 8) {
                                if let t = entry.threat_type, !t.isEmpty {
                                    Text("Загроза: \(t)")
                                }
                                if let src = entry.source_region, !src.isEmpty {
                                    let dst = entry.target_region ?? ""
                                    Text("Маршрут: \(src) → \(dst)")
                                }
                                if let reason = entry.reason, entry.rule_text != nil, !reason.isEmpty {
                                    Text("Причина: \(reason)")
                                }
                            }
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                }
            }
            .padding(14)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Tab 4: Errors (Помилки)
    
    private var errorsTabContent: some View {
        VStack(spacing: 16) {
            // Filters Section
            VStack(spacing: 8) {
                HStack {
                    Text("Фільтри")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    Picker("Джерело", selection: $errSourceFilter) {
                        Text("Всі").tag("")
                        Text("Server").tag("server")
                        Text("Firebase").tag("firebase")
                        Text("Gemini").tag("gemini")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    
                    Picker("Тип", selection: $errTypeFilter) {
                        Text("Всі").tag("")
                        Text("429 Ліміт").tag("429_rate_limit")
                        Text("500 Сервер").tag("500_server")
                        Text("Таймаут").tag("timeout")
                        Text("Мережа").tag("network_error")
                        Text("Авторизація").tag("auth")
                        Text("Системні").tag("systemic")
                        Text("Firebase").tag("firebase_error")
                        Text("Telegram").tag("telegram_error")
                        Text("Gemini").tag("gemini_api_error")
                        Text("JSON").tag("json_parse_error")
                        Text("База даних").tag("database_error")
                        Text("Валідація").tag("validation_error")
                        Text("Інші").tag("general")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    
                    Picker("Днів", selection: $errDaysFilter) {
                        Text("1 д").tag(1)
                        Text("3 д").tag(3)
                        Text("7 д").tag(7)
                        Text("30 д").tag(30)
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    
                    Button(action: {
                        Task { await fetchErrors() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(10)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)
            
            // Stats cards grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statBox(title: "Всього помилок", value: "\(errorStats?.total ?? 0)", color: .red)
                statBox(title: "429 Rate Limit", value: "\(errorStats?.by_type.first(where: { $0.error_type == "429_rate_limit" })?.count ?? 0)", color: .yellow)
                statBox(title: "Firebase", value: "\(errorStats?.by_source.first(where: { $0.source == "firebase" })?.count ?? 0)", color: .orange)
                statBox(title: "Gemini", value: "\(errorStats?.by_source.first(where: { $0.source == "gemini" })?.count ?? 0)", color: .purple)
            }
            
            // Swift Charts Section
            if let stats = errorStats {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Джерела помилок")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Chart {
                        ForEach(stats.by_source) { item in
                            BarMark(
                                x: .value("Count", item.count),
                                y: .value("Source", item.source)
                            )
                            .foregroundStyle(
                                item.source == "server" ? Color.blue :
                                item.source == "firebase" ? Color.orange : Color.purple
                            )
                        }
                    }
                    .frame(height: 120)
                }
                .padding(14)
                .background(ChartColorTheme.cardBg)
                .cornerRadius(12)
                
                // Hourly error chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Розподіл помилок за годинами (48г)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Chart {
                        ForEach(stats.hourly) { item in
                            BarMark(
                                x: .value("Hour", item.hour),
                                y: .value("Count", item.count)
                            )
                            .foregroundStyle(Color.red)
                        }
                    }
                    .frame(height: 120)
                }
                .padding(14)
                .background(ChartColorTheme.cardBg)
                .cornerRadius(12)
            }
            
            // Errors List Table
            VStack(alignment: .leading, spacing: 10) {
                Text("Записи помилок (\(errorsList.count))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                if errorsList.isEmpty {
                    Text("Не знайдено помилок за вибраний період 🎉")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    VStack(spacing: 8) {
                        ForEach(errorsList.prefix(50)) { error in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(error.source.uppercased())
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            error.source == "server" ? Color.blue.opacity(0.2) :
                                            error.source == "firebase" ? Color.orange.opacity(0.2) : Color.purple.opacity(0.2)
                                        )
                                        .foregroundColor(
                                            error.source == "server" ? Color.blue :
                                            error.source == "firebase" ? Color.orange : Color.purple
                                        )
                                        .cornerRadius(4)
                                    
                                    Text(formatErrorType(error.error_type))
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.15))
                                        .foregroundColor(.red)
                                        .cornerRadius(4)
                                    
                                    Spacer()
                                    
                                    Text(formatShortTime(error.timestamp))
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                
                                Text(error.message)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(2)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(14)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Tab 5: Control (Керування)
    
    private var controlTabContent: some View {
        VStack(spacing: 16) {
            // Interactive Threat Injection Panel (Redesigned)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(ChartColorTheme.cyan)
                    Text("Ручний інжектор загроз")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 10) {
                    HStack {
                        Text("Область:")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Picker("", selection: $simRegion) {
                            ForEach(regionsList, id: \.self) { r in
                                Text(r).tag(r)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(8)
                    
                    HStack {
                        Text("Рівень загрози:")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Picker("", selection: $simLevel) {
                            Text("Зелений (none)").tag("none")
                            Text("Жовтий (low)").tag("low")
                            Text("Помаранчевий (medium)").tag("medium")
                            Text("Червоний (high)").tag("high")
                            Text("Бордовий (critical)").tag("critical")
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(8)
                    
                    HStack {
                        Text("Тип загрози:")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Picker("", selection: $simThreatType) {
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
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Детальний опис загрози:")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                        TextField("Наприклад: Повідомляють про рух БПЛА...", text: $simDetail)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        triggerHaptic()
                        Task { await injectCustomThreat() }
                    }) {
                        HStack {
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
                    
                    if showSimSuccessMessage {
                        Text(simSuccessText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(14)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)

            
            // Server Diagnostics
            VStack(alignment: .leading, spacing: 12) {
                Text("Діагностика з'єднання")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 10) {
                    diagnosticsRow(name: "Сервер офіційних тривог", url: "ubilling.net.ua", status: alertsStatus)
                    Divider().background(Color.white.opacity(0.06))
                    diagnosticsRow(name: "Сервер аналітики (Premium)", url: "sirenua-threatserver.onrender.com", status: threatsStatus)
                    Divider().background(Color.white.opacity(0.06))
                    diagnosticsRow(name: "Аналізатор Gemini API", url: "gemini-3.1-flash-lite", status: geminiStatus)
                }
                .padding(.vertical, 4)
                
                Button(action: {
                    triggerHaptic()
                    alertsStatus = "Перевірка..."
                    threatsStatus = "Перевірка..."
                    geminiStatus = "Перевірка..."
                    Task { await performDiagnostics() }
                }) {
                    Text("Оновити діагностику")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(8)
                }
            }
            .padding(14)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)
            
            // Threat Simulation Scenarios (Extended)
            VStack(alignment: .leading, spacing: 12) {
                Text("Сценарії симуляції загроз")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Запустіть масові тестові сценарії для перевірки відображення загроз на карті, РЕБ та FCM пушів.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                    .lineSpacing(4)
                
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        simulationButton(title: "Шахеди (Південь)", scenario: "shaheds_south", color: .yellow)
                        simulationButton(title: "Зліт МіГ-31К", scenario: "mig_takeoff", color: .orange)
                    }
                    
                    HStack(spacing: 8) {
                        simulationButton(title: "Ракети (Захід)", scenario: "cruise_missiles_west", color: .blue)
                        simulationButton(title: "Балістика (Харків)", scenario: "ballistic_kharkiv", color: .red)
                    }
                    
                    HStack(spacing: 8) {
                        simulationButton(title: "💥 Масована атака", scenario: "massive_attack", color: .purple)
                        Button(action: {
                            triggerHaptic()
                            Task { await postClearAll() }
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Очистити все")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.red.opacity(0.25))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.4), lineWidth: 1))
                        }
                    }
                }
            }
            .padding(14)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)
        }
    }
    
    private func simulationButton(title: String, scenario: String, color: Color) -> some View {
        Button(action: {
            triggerHaptic()
            Task { await postTriggerScenario(scenario) }
        }) {
            HStack {
                Image(systemName: "play.fill")
                Text(title)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(color.opacity(0.2))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.4), lineWidth: 1))
        }
    }
    
    private func diagnosticsRow(name: String, url: String, status: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text(url)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            
            Text(status)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(
                    status == "ONLINE" || status == "OK" ? .green :
                    status == "Перевірка..." ? .gray : .red
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    status == "ONLINE" || status == "OK" ? Color.green.opacity(0.12) :
                    status == "Перевірка..." ? Color.gray.opacity(0.12) : Color.red.opacity(0.12)
                )
                .cornerRadius(6)
        }
    }
    
    // MARK: - Networking & API Logic
    
    private func refreshCurrentTab() async {
        switch selectedTab {
        case 0:
            await fetchDashboardStats()
        case 1:
            await fetchCorrelationV2()
        case 2:
            await fetchChronology()
        case 3:
            await fetchRules()
        case 4:
            await fetchErrors()
        default:
            await performDiagnostics()
        }
    }
    
    private func refreshAllData() async {
        isLoading = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchDashboardStats() }
            group.addTask { await self.fetchCorrelationV2() }
            group.addTask { await self.fetchChronology() }
            group.addTask { await self.fetchRules() }
            group.addTask { await self.fetchErrors() }
            group.addTask { await self.performDiagnostics() }
        }
        isLoading = false
    }
    
    private func fetchDashboardStats() async {
        let url = URL(string: "\(serverURL)/api/admin/dashboard/stats")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let decoded = try? JSONDecoder().decode(AdminDashboardStatsResponse.self, from: data) {
                self.dashboardStats = decoded
            }
        } catch {}
    }
    
    private func fetchCorrelationV2() async {
        var params = ""
        
        if corUseDateRange {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let fromStr = formatter.string(from: corDateFrom)
            let toStr = formatter.string(from: corDateTo)
            params = "date_from=\(fromStr)&date_to=\(toStr)"
        } else {
            params = "days=\(corDaysFilter)"
        }
        
        if !corRegionFilter.isEmpty {
            if let escaped = corRegionFilter.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                params += "&region=\(escaped)"
            }
        }
        if !corThreatTypeFilter.isEmpty {
            params += "&threat_type=\(corThreatTypeFilter)"
        }
        if !corMatchFilter.isEmpty {
            params += "&match_result=\(corMatchFilter)"
        }
        
        let url = URL(string: "\(serverURL)/api/admin/chronology/v2?\(params)")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let decoded = try? JSONDecoder().decode(AdminChronologyV2Response.self, from: data) {
                self.correlationV2Data = decoded
            }
        } catch {}
    }
    
    private func fetchChronology() async {
        var params = "days=\(daysFilter)"
        if !chrRegionFilter.isEmpty {
            if let escaped = chrRegionFilter.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                params += "&region=\(escaped)"
            }
        }
        if !chrThreatTypeFilter.isEmpty {
            params += "&threat_type=\(chrThreatTypeFilter)"
        }
        if !chrMatchFilter.isEmpty {
            params += "&prediction_accuracy=\(chrMatchFilter)"
        }
        
        let url = URL(string: "\(serverURL)/api/admin/chronology?\(params)")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let decoded = try? JSONDecoder().decode(AdminChronologyResponse.self, from: data) {
                self.chronologyData = decoded
            }
        } catch {}
    }
    
    private func fetchRules() async {
        var rulesParams = "active_only=true&limit=100"
        if !rulesTypeFilter.isEmpty {
            rulesParams += "&rule_type=\(rulesTypeFilter)"
        }
        if !rulesThreatTypeFilter.isEmpty {
            rulesParams += "&threat_type=\(rulesThreatTypeFilter)"
        }
        
        var auditParams = "days=\(rulesDaysFilter)"
        if !rulesTypeFilter.isEmpty {
            auditParams += "&rule_type=\(rulesTypeFilter)"
        }
        if !rulesThreatTypeFilter.isEmpty {
            auditParams += "&threat_type=\(rulesThreatTypeFilter)"
        }
        if !rulesActionFilter.isEmpty {
            auditParams += "&action=\(rulesActionFilter)"
        }
        
        do {
            let rulesUrl = URL(string: "\(serverURL)/api/analytics/rules?\(rulesParams)")!
            let historyUrl = URL(string: "\(serverURL)/api/admin/rules/history?\(auditParams)")!
            
            let (rulesData, _) = try await URLSession.shared.data(from: rulesUrl)
            let (historyData, _) = try await URLSession.shared.data(from: historyUrl)
            
            if let decodedRules = try? JSONDecoder().decode(GeminiRulesResponse.self, from: rulesData) {
                self.activeRules = decodedRules.rules
            }
            
            if let decodedHistory = try? JSONDecoder().decode(GeminiRulesHistoryResponse.self, from: historyData) {
                self.ruleAuditHistory = decodedHistory.entries
            }
        } catch {}
    }
    
    private func fetchErrors() async {
        let params = "days=\(errDaysFilter)" + (errSourceFilter.isEmpty ? "" : "&source=\(errSourceFilter)") + (errTypeFilter.isEmpty ? "" : "&error_type=\(errTypeFilter)")
        
        do {
            let statsUrl = URL(string: "\(serverURL)/api/admin/errors/stats?days=\(errDaysFilter)")!
            let errorsUrl = URL(string: "\(serverURL)/api/admin/errors?\(params)")!
            
            let (statsData, _) = try await URLSession.shared.data(from: statsUrl)
            let (errorsData, _) = try await URLSession.shared.data(from: errorsUrl)
            
            if let decodedStats = try? JSONDecoder().decode(AdminErrorStatsResponse.self, from: statsData) {
                self.errorStats = decodedStats
            }
            
            if let decodedErrors = try? JSONDecoder().decode(AdminErrorsResponse.self, from: errorsData) {
                self.errorsList = decodedErrors.errors
            }
        } catch {}
    }
    
    private func loadRegions() async {
        let url = URL(string: "\(serverURL)/api/threats")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let threats = json["threats"] as? [String: Any] {
                self.regionsList = threats.keys.sorted()
            }
        } catch {}
    }
    
    private func performDiagnostics() async {
        // 1. Alerts server ping
        do {
            var req = URLRequest(url: URL(string: "https://ubilling.net.ua/aerialalerts/")!)
            req.timeoutInterval = 3.0
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                alertsStatus = "ONLINE"
            } else {
                alertsStatus = "ERROR"
            }
        } catch { alertsStatus = "OFFLINE" }
        
        // 2. Analytics threat server ping
        do {
            var req = URLRequest(url: URL(string: "\(serverURL)/api/threats")!)
            req.timeoutInterval = 3.0
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                threatsStatus = "ONLINE"
            } else {
                threatsStatus = "ERROR"
            }
        } catch { threatsStatus = "OFFLINE" }
        
        // 3. Gemini status ping
        do {
            var req = URLRequest(url: URL(string: "\(serverURL)/api/gemini/status")!)
            req.timeoutInterval = 3.0
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String {
                geminiStatus = status.uppercased()
            } else {
                geminiStatus = "UNKNOWN"
            }
        } catch { geminiStatus = "OFFLINE" }
    }
    
    private func rebuildRules() async {
        do {
            var req = URLRequest(url: URL(string: "\(serverURL)/api/analytics/rules/rebuild")!)
            req.httpMethod = "POST"
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                showRebuildSuccess = true
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                showRebuildSuccess = false
                await fetchRules()
            }
        } catch {}
    }
    
    private func injectCustomThreat() async {
        do {
            var req = URLRequest(url: URL(string: "\(serverURL)/api/threats/mock")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "region": simRegion,
                "level": simLevel,
                "threat_type": simThreatType,
                "detail": simDetail
            ]
            
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            let (data, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse {
                if http.statusCode == 200 {
                    simSuccessText = "✅ Загрозу успішно надіслано в \(simRegion)!"
                    showSimSuccessMessage = true
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    showSimSuccessMessage = false
                } else {
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let detail = errorJson["detail"] as? String {
                        simSuccessText = "⚠️ Помилка: \(detail)"
                    } else {
                        simSuccessText = "⚠️ Помилка сервера (\(http.statusCode))"
                    }
                    showSimSuccessMessage = true
                }
            }
        } catch {
            simSuccessText = "⚠️ Помилка мережі: \(error.localizedDescription)"
            showSimSuccessMessage = true
        }
    }
    
    private func postTriggerScenario(_ scenario: String) async {
        do {
            var req = URLRequest(url: URL(string: "\(serverURL)/api/threats/scenario")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ["scenario": scenario]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                await fetchChronology()
            }
        } catch {}
    }
    
    private func postClearAll() async {
        do {
            var req = URLRequest(url: URL(string: "\(serverURL)/api/threats/clear")!)
            req.httpMethod = "POST"
            let (_, res) = try await URLSession.shared.data(for: req)
            if let http = res as? HTTPURLResponse, http.statusCode == 200 {
                await fetchChronology()
            }
        } catch {}
    }
    
    // MARK: - Format helpers
    
    private func formatShortTime(_ ts: String) -> String {
        guard ts.count >= 19 else { return ts }
        let cleanTs = ts.replacingOccurrences(of: "T", with: " ")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        if let date = formatter.date(from: String(cleanTs.prefix(19))) {
            let localFormatter = DateFormatter()
            localFormatter.timeStyle = .short
            localFormatter.dateStyle = .short
            localFormatter.timeZone = TimeZone.current
            return localFormatter.string(from: date)
        }
        return String(ts.suffix(8))
    }
    
    private func formatShortDate(_ dateStr: String) -> String {
        guard dateStr.count >= 10 else { return dateStr }
        return String(dateStr.suffix(5))
    }
    
    private func formatDuration(_ sec: Int) -> String {
        let positiveSec = abs(sec)
        if positiveSec < 60 { return "\(positiveSec)с" }
        if positiveSec < 3600 { return "\(positiveSec / 60)хв" }
        return "\(positiveSec / 3600)год"
    }
    
    private func formatErrorType(_ type: String) -> String {
        switch type {
        case "429_rate_limit": return "429 Ліміт запитів"
        case "500_server": return "500 Помилка сервера"
        case "timeout": return "Таймаут з'єднання"
        case "network_error": return "Мережевий збій"
        case "auth": return "Помилка автентифікації"
        case "systemic": return "Системна помилка"
        case "firebase_error": return "Firebase/FCM збій"
        case "telegram_error": return "Telegram API збій"
        case "gemini_api_error": return "Gemini API збій"
        case "json_parse_error": return "Помилка парсингу JSON"
        case "database_error": return "Помилка бази даних"
        case "validation_error": return "Помилка валідації"
        case "general": return "Загальна помилка"
        default: return type
        }
    }

    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
    
    private func legendItem(title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private func triggerHaptic(_ style: String = "medium") {
        #if canImport(UIKit)
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case "light": feedbackStyle = .light
        case "heavy": feedbackStyle = .heavy
        default: feedbackStyle = .medium
        }
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
        #endif
    }
}
