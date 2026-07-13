import SwiftUI
import Charts

struct AdminChronologyTab: View {
    @ObservedObject var viewModel: AdminViewModel
    
    var body: some View {
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
                    Picker("", selection: $viewModel.daysFilter) {
                        Text("1 день").tag(1)
                        Text("3 дні").tag(3)
                        Text("7 днів").tag(7)
                        Text("14 днів").tag(14)
                        Text("30 днів").tag(30)
                    }
                    .pickerStyle(.menu)
                }
                
                HStack(spacing: 8) {
                    Picker("Регіон", selection: $viewModel.chrRegionFilter) {
                        Text("Всі області").tag("")
                        ForEach(viewModel.regionsList, id: \.self) { r in
                            Text(r).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    Picker("Загроза", selection: $viewModel.chrThreatTypeFilter) {
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
                    Picker("Результат", selection: $viewModel.chrMatchFilter) {
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
                        Task { await viewModel.fetchChronology() }
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
            
            VStack(spacing: 16) {
                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    statBox(title: "Всього подій", value: "\(viewModel.chronologyData?.total ?? 0)", color: ChartColorTheme.accent)
                    statBox(title: "✅ Співпадіння AI", value: "\(viewModel.chronologyData?.events.filter({ $0.match_type == "confirmed" }).count ?? 0)", color: ChartColorTheme.confirmed)
                    statBox(title: "🛡️ Збито/РЕБ", value: "\(viewModel.chronologyData?.events.filter({ $0.match_type == "mitigated" }).count ?? 0)", color: ChartColorTheme.mitigated)
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    statBox(title: "❌ Неспівпадіння", value: "\(viewModel.chronologyData?.events.filter({ $0.match_type == "overestimated" }).count ?? 0)", color: ChartColorTheme.overestimated)
                    statBox(title: "⏱️ Активні", value: "\(viewModel.chronologyData?.events.filter({ $0.match_type == "active" }).count ?? 0)", color: ChartColorTheme.active)
                }
                    
                    if let chrono = viewModel.chronologyData {
                        /*
                        let dailyStatsWithAccuracy: [SimpleStat] = chrono.daily_stats.compactMap { item -> SimpleStat? in
                            guard let pct = item.accuracyPct else { return nil }
                            let formatted = viewModel.formatShortDate(item.day)
                            return SimpleStat(day: item.day, formattedDay: formatted, accuracy: pct)
                        }
                        */
                        // Daily Chart for Total Alerts vs Cleared
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Загрози та відбої по днях")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Chart {
                                ForEach(chrono.daily_stats) { item in
                                    BarMark(
                                        x: .value("Day", viewModel.formatShortDate(item.day)),
                                        y: .value("Загрози", item.total_events)
                                    )
                                    .foregroundStyle(Color.red.opacity(0.8))
                                    
                                    BarMark(
                                        x: .value("Day", viewModel.formatShortDate(item.day)),
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
                        
                        // Grouped Timeline list
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Стрічка подій хронології")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            
                            if viewModel.groupedChronologyEvents.isEmpty {
                                Text("Немає подій за вибраними фільтрами.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 30)
                            } else {
                                ForEach(viewModel.groupedChronologyEvents, id: \.0) { day, events in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("📅 \(day) (\(events.count) подій)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white.opacity(0.6))
                                            .padding(.top, 8)
                                            .padding(.bottom, 2)
                                        
                                        ForEach(events) { ev in
                                            ChronologyEventRow(ev: ev, viewModel: viewModel)
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
        .onChange(of: viewModel.daysFilter) { _, _ in
            Task { await viewModel.fetchChronology() }
        }
        .onChange(of: viewModel.chrRegionFilter) { _, _ in
            Task { await viewModel.fetchChronology() }
        }
        .onChange(of: viewModel.chrThreatTypeFilter) { _, _ in
            Task { await viewModel.fetchChronology() }
        }
        .onChange(of: viewModel.chrMatchFilter) { _, _ in
            Task { await viewModel.fetchChronology() }
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
}

struct SimpleStat: Identifiable {
    let id = UUID()
    let day: String
    let formattedDay: String
    let accuracy: Double
}

struct ChronologyEventRow: View {
    let ev: AdminChronologyEntry
    let viewModel: AdminViewModel
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(ev.match_type == "confirmed" ? "✅" :
                 ev.match_type == "mitigated" ? "🛡️" :
                 ev.match_type == "overestimated" ? "❌" :
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
                        Text(viewModel.formatDuration(duration))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                Text(ev.threat_type == "official_alarm" ? "Офіційна тривога" : "\(ev.threat_type ?? "Загроза") (\(ev.threat_level ?? "none"))")
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
                        Text("Початок: \(viewModel.formatShortTime(tts))")
                    }
                    if let cts = ev.clearing_timestamp {
                        Text(" · Відбій: \(viewModel.formatShortTime(cts))")
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
