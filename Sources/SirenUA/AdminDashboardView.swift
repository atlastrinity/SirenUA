import SwiftUI
import Charts
import SafariServices

// MARK: - API Decodable Models

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
    var id: String { source }
    let source: String
    let count: Int
}

struct TypeStat: Codable, Identifiable {
    var id: String { error_type }
    let error_type: String
    let count: Int
}

struct HourlyStat: Codable, Identifiable {
    var id: String { hour }
    let hour: String
    let count: Int
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
    var id: String { day }
    let day: String
    let total_events: Int
    let cleared: Int
    let active: Int
    let confirmed: Int
    let overestimated: Int
    let predictive: Int
}

struct AdminChronologyResponse: Codable {
    let total: Int
    let days: Int
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

// MARK: - AdminDashboardView

struct AdminDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var daysFilter = 7
    @State private var sourceFilter = ""
    @State private var typeFilter = ""
    @State private var regionFilter = ""
    
    // Server status pings
    @State private var alertsStatus: String = "Перевірка..."
    @State private var threatsStatus: String = "Перевірка..."
    @State private var geminiStatus: String = "Перевірка..."
    
    // Errors Tab Data
    @State private var totalErrorsCount = 0
    @State private var err429Count = 0
    @State private var firebaseErrorsCount = 0
    @State private var geminiErrorsCount = 0
    @State private var errorStats: AdminErrorStatsResponse? = nil
    @State private var errorsList: [AdminErrorEntry] = []
    
    // Chronology Tab Data
    @State private var chronologyData: AdminChronologyResponse? = nil
    @State private var activeThreatsCount = 0
    @State private var matchCount = 0
    @State private var mismatchCount = 0
    
    // Rules Tab Data
    @State private var activeRules: [GeminiRule] = []
    @State private var ruleAuditHistory: [GeminiRuleAuditEntry] = []
    @State private var rulesDaysFilter = 30
    
    // Loading State
    @State private var isLoading = false
    @State private var showRebuildSuccess = false
    
    private let serverURL = "https://sirenua-threatserver.onrender.com"

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.07, blue: 0.10).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("🚨 SirenUA Admin Panel")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Нативний моніторинг")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        Spacer()
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dismiss()
                        }) {
                            Text("Готово")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.blue.opacity(0.3))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.09, green: 0.11, blue: 0.15))
                    
                    // Segmented Tab Control
                    Picker("", selection: $selectedTab) {
                        Text("Помилки").tag(0)
                        Text("Хронологія").tag(1)
                        Text("AI Правила").tag(2)
                        Text("Керування").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.07, green: 0.09, blue: 0.12))
                    
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
                                    errorsTabContent
                                case 1:
                                    chronologyTabContent
                                case 2:
                                    rulesTabContent
                                default:
                                    controlTabContent
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                            .padding(.bottom, 32)
                        }
                        .refreshable {
                            await refreshAllData()
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
            .task {
                await refreshAllData()
            }
        }
    }
    
    // MARK: - Tab: Errors
    
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
                    Picker("Джерело", selection: $sourceFilter) {
                        Text("Всі").tag("")
                        Text("Server").tag("server")
                        Text("Firebase").tag("firebase")
                        Text("Gemini").tag("gemini")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    
                    Picker("Тип", selection: $typeFilter) {
                        Text("Всі").tag("")
                        Text("429").tag("429_rate_limit")
                        Text("500").tag("500_server")
                        Text("Timeout").tag("timeout")
                        Text("General").tag("general")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    
                    Picker("Днів", selection: $daysFilter) {
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
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
            
            // Stats cards grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statBox(title: "Всього помилок", value: "\(totalErrorsCount)", color: .red)
                statBox(title: "429 Rate Limit", value: "\(err429Count)", color: .yellow)
                statBox(title: "Firebase", value: "\(firebaseErrorsCount)", color: .orange)
                statBox(title: "Gemini", value: "\(geminiErrorsCount)", color: .purple)
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
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                
                // Hourly Timeline Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Динаміка помилок (Line Chart)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Chart {
                        ForEach(stats.hourly) { item in
                            LineMark(
                                x: .value("Hour", String(item.hour.suffix(5))),
                                y: .value("Count", item.count)
                            )
                            .foregroundStyle(Color.red)
                            .symbol(Circle())
                        }
                    }
                    .frame(height: 140)
                }
                .padding(14)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
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
                                        .font(.system(size: 10, weight: .bold))
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
                                    
                                    Text(error.error_type)
                                        .font(.system(size: 10, weight: .bold))
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
                                
                                if let ep = error.endpoint {
                                    Text("Endpoint: \(ep)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
    
    // MARK: - Tab: Chronology
    
    private var chronologyTabContent: some View {
        VStack(spacing: 16) {
            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statBox(title: "Всього подій", value: "\(chronologyData?.total ?? 0)", color: .blue)
                statBox(title: "⏱️ Активні тривоги", value: "\(activeThreatsCount)", color: .yellow)
                statBox(title: "✅ Співпадіння AI", value: "\(matchCount)", color: .green)
                statBox(title: "❌ Неспівпадіння AI", value: "\(mismatchCount)", color: .red)
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
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                
                // Accuracy Line Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Точність передбачень ШІ (%)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Chart {
                        ForEach(chrono.daily_stats) { item in
                            let total = item.confirmed + item.overestimated
                            let pct = total > 0 ? Double(item.confirmed) / Double(total) * 100.0 : nil
                            if let val = pct {
                                LineMark(
                                    x: .value("Day", formatShortDate(item.day)),
                                    y: .value("Точність %", val)
                                )
                                .foregroundStyle(Color.green)
                                .symbol(Circle())
                            }
                        }
                    }
                    .chartYScale(range: .plotDimension(padding: 10))
                    .frame(height: 140)
                }
                .padding(14)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                
                // Timeline list
                VStack(alignment: .leading, spacing: 12) {
                    Text("Стрічка подій хронології")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    ForEach(chrono.events.prefix(40)) { ev in
                        HStack(alignment: .top, spacing: 8) {
                            Text(ev.match_type == "match" ? "✅" :
                                 ev.match_type == "mismatch" ? "❌" :
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
                                
                                Text("\(ev.threat_type) (\(ev.threat_level))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                
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
                                    if let res = ev.resolution_type, !res.isEmpty, res != "unknown" {
                                        let label = res == "impact" ? "💥 Влучання" : 
                                                    res == "intercepted" ? "🛡️ Збито" : res
                                        Text(" · \(label)")
                                            .foregroundColor(res == "impact" ? .red.opacity(0.8) : .green.opacity(0.8))
                                            .fontWeight(.bold)
                                    }
                                }
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.35))
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.01))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.03))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
        }
    }
    
    // MARK: - Tab: Rules
    
    private var rulesTabContent: some View {
        VStack(spacing: 16) {
            // Rules days filter
            HStack {
                Text("Днів аудиту:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Picker("", selection: $rulesDaysFilter) {
                    Text("7 днів").tag(7)
                    Text("14 днів").tag(14)
                    Text("30 днів").tag(30)
                }
                .pickerStyle(.menu)
                .tint(.white)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .onChange(of: rulesDaysFilter) { oldValue, newValue in
                    Task { await fetchRules() }
                }
                
                Spacer()
            }
            .padding(10)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
            
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
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(rule.rule_type)
                                    .font(.system(size: 10, weight: .bold))
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
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
            
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
                                    .font(.system(size: 10, weight: .bold))
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
                            
                            if let text = entry.rule_text {
                                Text(text)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                            } else if let reason = entry.reason {
                                Text(reason)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            
                            if let t = entry.threat_type {
                                Text("Тип загрози: \(t)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
    
    // MARK: - Tab: Control
    
    private var controlTabContent: some View {
        VStack(spacing: 16) {
            // Rebuild rules section
            VStack(alignment: .leading, spacing: 12) {
                Text("Самонавчання ШІ (Gemini)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Запуск примусового аналізуpaired_events для генерації нових правил або оновлення наявних.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                    .lineSpacing(4)
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task { await rebuildRules() }
                }) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                        Text("Перебудувати правила навчання")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple.opacity(0.3))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.5), lineWidth: 1))
                }
                
                if showRebuildSuccess {
                    Text("✅ Правила успішно перебудовано на сервері!")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.top, 4)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
            
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
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
            
            // Threat Simulation
            VStack(alignment: .leading, spacing: 12) {
                Text("Симуляція загроз (Розробка)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Запустіть тестові сценарії для перевірки відображення загроз на карті та перевірки логіки FCM пушів.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
                    .lineSpacing(4)
                
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        simulationButton(title: "Шахеди з півдня", scenario: "shaheds_south", color: .yellow)
                        simulationButton(title: "Зліт МіГ-31К", scenario: "mig_takeoff", color: .orange)
                    }
                    
                    HStack(spacing: 8) {
                        simulationButton(title: "Ракети (Захід)", scenario: "cruise_missiles_west", color: .blue)
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
            .background(Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
    
    private func simulationButton(title: String, scenario: String, color: Color) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
    
    // MARK: - API Networking helpers
    
    private func refreshAllData() async {
        isLoading = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchErrors() }
            group.addTask { await self.fetchChronology() }
            group.addTask { await self.fetchRules() }
            group.addTask { await self.performDiagnostics() }
        }
        isLoading = false
    }
    
    private func fetchErrors() async {
        let params = "days=\(daysFilter)" + (sourceFilter.isEmpty ? "" : "&source=\(sourceFilter)") + (typeFilter.isEmpty ? "" : "&error_type=\(typeFilter)")
        
        do {
            let statsUrl = URL(string: "\(serverURL)/api/admin/errors/stats?days=\(daysFilter)")!
            let errorsUrl = URL(string: "\(serverURL)/api/admin/errors?\(params)")!
            
            let (statsData, _) = try await URLSession.shared.data(from: statsUrl)
            let (errorsData, _) = try await URLSession.shared.data(from: errorsUrl)
            
            if let decodedStats = try? JSONDecoder().decode(AdminErrorStatsResponse.self, from: statsData) {
                self.errorStats = decodedStats
                self.totalErrorsCount = decodedStats.total
                
                let r429 = decodedStats.by_type.first(where: { $0.error_type == "429_rate_limit" })
                self.err429Count = r429?.count ?? 0
                let fb = decodedStats.by_source.first(where: { $0.source == "firebase" })
                self.firebaseErrorsCount = fb?.count ?? 0
                let gem = decodedStats.by_source.first(where: { $0.source == "gemini" })
                self.geminiErrorsCount = gem?.count ?? 0
            }
            
            if let decodedErrors = try? JSONDecoder().decode(AdminErrorsResponse.self, from: errorsData) {
                self.errorsList = decodedErrors.errors
            }
        } catch {}
    }
    
    private func fetchChronology() async {
        let url = URL(string: "\(serverURL)/api/admin/chronology?days=\(daysFilter)")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let decoded = try? JSONDecoder().decode(AdminChronologyResponse.self, from: data) {
                self.chronologyData = decoded
                self.activeThreatsCount = decoded.events.filter({ $0.match_type == "active" }).count
                self.matchCount = decoded.events.filter({ $0.match_type == "match" }).count
                self.mismatchCount = decoded.events.filter({ $0.match_type == "mismatch" }).count
            }
        } catch {}
    }
    
    private func fetchRules() async {
        do {
            let rulesUrl = URL(string: "\(serverURL)/api/analytics/rules?active_only=true")!
            let historyUrl = URL(string: "\(serverURL)/api/admin/rules/history?days=\(rulesDaysFilter)")!
            
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
    
    // MARK: - Date/Format Helpers
    
    private func formatShortTime(_ ts: String) -> String {
        // Input format: YYYY-MM-DD HH:MM:SS (UTC)
        guard ts.count >= 19 else { return ts }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        if let date = formatter.date(from: String(ts.prefix(19))) {
            let localFormatter = DateFormatter()
            localFormatter.timeStyle = .medium
            localFormatter.dateStyle = .none
            localFormatter.timeZone = TimeZone.current
            return localFormatter.string(from: date)
        }
        return String(ts.suffix(8))
    }
    
    private func formatShortDate(_ dateStr: String) -> String {
        // Input format: YYYY-MM-DD
        guard dateStr.count >= 10 else { return dateStr }
        return String(dateStr.suffix(5)) // MM-DD
    }
    
    private func formatDuration(_ sec: Int) -> String {
        if sec < 60 { return "\(sec)с" }
        if sec < 3600 { return "\(sec / 60)хв" }
        return "\(sec / 3600)год"
    }

    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
