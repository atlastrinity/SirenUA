import SwiftUI
import Charts

struct AdminCorrelationTab: View {
    @ObservedObject var viewModel: AdminViewModel
    
    var body: some View {
        VStack(spacing: 14) {
            filtersPanel()
            
            if let corr = viewModel.correlationV2Data {
                correlationContent(corr: corr)
            }
        }
        .onChange(of: viewModel.corDaysFilter) { _, _ in
            Task { await viewModel.fetchCorrelationV2() }
        }
        .onChange(of: viewModel.corRegionFilter) { _, _ in
            Task { await viewModel.fetchCorrelationV2() }
        }
        .onChange(of: viewModel.corThreatTypeFilter) { _, _ in
            Task { await viewModel.fetchCorrelationV2() }
        }
        .onChange(of: viewModel.corMatchFilter) { _, _ in
            Task { await viewModel.fetchCorrelationV2() }
        }
        .onChange(of: viewModel.corUseDateRange) { _, _ in
            Task { await viewModel.fetchCorrelationV2() }
        }
        .onChange(of: viewModel.corDateFrom) { _, _ in
            Task { await viewModel.fetchCorrelationV2() }
        }
        .onChange(of: viewModel.corDateTo) { _, _ in
            Task { await viewModel.fetchCorrelationV2() }
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

    @ViewBuilder
    private func correlationContent(corr: AdminChronologyV2Response) -> some View {
        VStack(spacing: 14) {
            // Dynamic stats counters
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                statBox(title: "Всього", value: "\(corr.total ?? 0)", color: .white)
                statBox(title: "✅ Підтверджено", value: "\(corr.stats?["confirmed"] ?? 0)", color: ChartColorTheme.confirmed)
                statBox(title: "🛡️ Збито", value: "\(corr.stats?["mitigated"] ?? 0)", color: ChartColorTheme.mitigated)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                statBox(title: "❌ Помилкові", value: "\(corr.stats?["overestimated"] ?? 0)", color: ChartColorTheme.overestimated)
                statBox(title: "⏱️ Активні", value: "\(corr.stats?["active"] ?? 0)", color: ChartColorTheme.active)
            }
            
            dailyAccuracyChart(corr: corr)
            
            let buckets = getSortedBuckets(corr.delta_distribution ?? [:])
            if !buckets.isEmpty {
                deltaDistributionChart(buckets: buckets)
            }
            
            if !(corr.type_breakdown ?? []).isEmpty {
                typeBreakdownChart(corr: corr)
            }
            
            correlationList(corr: corr)
        }
    }

    @ViewBuilder
    private func dailyAccuracyChart(corr: AdminChronologyV2Response) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Динаміка аналізу AI за днями")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
            
            Chart {
                ForEach(corr.daily_stats ?? []) { item in
                    BarMark(
                        x: .value("Day", viewModel.formatShortDate(item.day)),
                        y: .value("Confirmed", item.confirmed)
                    )
                    .foregroundStyle(ChartColorTheme.confirmed)
                    
                    BarMark(
                        x: .value("Day", viewModel.formatShortDate(item.day)),
                        y: .value("Mitigated", item.mitigated)
                    )
                    .foregroundStyle(ChartColorTheme.mitigated)
                    
                    BarMark(
                        x: .value("Day", viewModel.formatShortDate(item.day)),
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
    }
    
    @ViewBuilder
    private func deltaDistributionChart(buckets: [DeltaDistributionBucket]) -> some View {
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
    
    @ViewBuilder
    private func typeBreakdownChart(corr: AdminChronologyV2Response) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🚀 Результати ШІ по типу загрози")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
            
            Chart {
                ForEach(corr.type_breakdown ?? []) { item in
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
    
    @ViewBuilder
    private func correlationList(corr: AdminChronologyV2Response) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Детальна кореляція (\(corr.events?.count ?? 0))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            if viewModel.groupedCorrelationEvents.isEmpty {
                Text("Немає подій за вибраними фільтрами.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else {
                ForEach(viewModel.groupedCorrelationEvents, id: \.0) { day, events in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("📅 \(day) (\(events.count) детекцій)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 8)
                            .padding(.bottom, 2)
                        
                        ForEach(events) { ev in
                            CorrelationEventRow(ev: ev, viewModel: viewModel)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(14)
    }

    private func formatAccuracyStatus(_ status: String?) -> String {
        switch status {
        case "confirmed": return "Підтверджено"
        case "mitigated": return "Збито/РЕБ"
        case "overestimated": return "Помилково"
        default: return "Інше"
        }
    }
    
    @ViewBuilder
    private func filtersPanel() -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("Фільтрація подій")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Toggle("Діапазон дат", isOn: $viewModel.corUseDateRange)
                    .labelsHidden()
                    .tint(.blue)
            }
            
            if viewModel.corUseDateRange {
                DatePicker("Від:", selection: $viewModel.corDateFrom, displayedComponents: .date)
                    .font(.system(size: 12))
                DatePicker("До:", selection: $viewModel.corDateTo, displayedComponents: .date)
                    .font(.system(size: 12))
            } else {
                HStack {
                    Text("Період:")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $viewModel.corDaysFilter) {
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
                Picker("Регіон", selection: $viewModel.corRegionFilter) {
                    Text("Всі області").tag("")
                    ForEach(viewModel.regionsList, id: \.self) { r in
                        Text(r).tag(r)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                
                Picker("Загроза", selection: $viewModel.corThreatTypeFilter) {
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
                Picker("Результат", selection: $viewModel.corMatchFilter) {
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
                    Task { await viewModel.fetchCorrelationV2() }
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
    }
}

struct CorrelationEventRow: View {
    let ev: AdminChronologyV2Entry
    let viewModel: AdminViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title line
            HStack {
                Text(ev.match_type ?? "" == "confirmed" ? "✅" :
                     ev.match_type ?? "" == "mitigated" ? "🛡️" :
                     ev.match_type ?? "" == "overestimated" ? "❌" :
                     ev.match_type ?? "" == "active" ? "⏱️" : "🔄")
                
                Text(ev.region ?? "Невідома область")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(ev.threat_level ?? "none")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (ev.threat_level ?? "none") == "high" ? Color.red.opacity(0.2) : Color.yellow.opacity(0.2)
                    )
                    .foregroundColor(
                        (ev.threat_level ?? "none") == "high" ? Color.red : Color.yellow
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
                metaRow(label: "AI детекція:", value: ev.ai_timestamp != nil ? viewModel.formatShortTime(ev.ai_timestamp!) : "—")
                metaRow(label: "Офіційна тривога:", value: ev.alarm_timestamp != nil ? viewModel.formatShortTime(ev.alarm_timestamp!) : "—")
                
                if let delta = ev.time_delta_seconds {
                    let sign = delta > 0 ? "+" : ""
                    metaRow(label: "Δ Час:", value: "\(sign)\(viewModel.formatDuration(delta))", color: delta >= 0 ? .green : .red)
                } else {
                    metaRow(label: "Δ Час:", value: "—")
                }
                
                metaRow(label: "Тривалість:", value: ev.duration_seconds != nil ? viewModel.formatDuration(ev.duration_seconds!) : "—")
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
}
