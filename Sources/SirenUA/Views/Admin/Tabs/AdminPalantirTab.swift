import SwiftUI
import Charts

struct AdminPalantirTab: View {
    @ObservedObject var viewModel: AdminViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Palantir Tactical Header
            palantirHeaderView
            
            if let overview = viewModel.palantirOverview {
                // Tactical Metrics Grid
                tacticalMetricsGrid(overview)
                
                // Synthesis Action Banner
                synthesisActionBanner
                
                // Multi-Hop Markov Flight Chains (NEW v2.5)
                multiHopChainsCard(overview)
                
                // Junction Hub Branching Probabilities (NEW v2.5)
                junctionBranchesCard(overview)
                
                // Air Defense Attrition & Density (NEW v2.5)
                airDefenseAttritionCard(overview)
                
                // Trajectory Vectors Card
                trajectoryVectorsCard(overview)
                
                // Launch Hubs Monitor
                launchHubsCard(overview)
                
                // Regional Risk Matrix Chart
                regionalRiskCard(overview)
                
                // Palantir Historical Intelligence Reports
                palantirReportsCard
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.cyan)
                    Text("Завантаження тактичної розвідки Palantir...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.vertical, 40)
            }
        }
        .task {
            await viewModel.fetchPalantirOverview()
        }
    }
    
    // MARK: - Header
    
    private var palantirHeaderView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "eye.trianglebadge.exclamationmark.fill")
                        .foregroundColor(.cyan)
                        .font(.system(size: 18))
                    Text("PALANTIR TACTICAL INTELLIGENCE")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                
                HStack(spacing: 4) {
                    ForEach([1, 7, 30, 90], id: \.self) { d in
                        Button(action: {
                            viewModel.triggerHaptic("light")
                            viewModel.palantirDaysFilter = d
                            Task { await viewModel.fetchPalantirOverview() }
                        }) {
                            Text("\(d)д")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(viewModel.palantirDaysFilter == d ? .black : .white.opacity(0.7))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(viewModel.palantirDaysFilter == d ? Color.cyan : Color.white.opacity(0.08))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            Text("Автономне трекування траєкторій, багатокрокових ланцюжків Маркова, пускових хабів та щільності ППО")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ChartColorTheme.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Tactical Metrics Grid
    
    private func tacticalMetricsGrid(_ overview: PalantirOverviewResponse) -> some View {
        let chainsCount = overview.multihop_chains?.count ?? 0
        let corridorsCount = overview.trajectory_corridors?.count ?? 0
        let hubsCount = overview.launch_hubs?.count ?? 0
        let avgConf = overview.trajectory_corridors?.compactMap { $0.avg_confidence }.reduce(0, +) ?? 0
        let avgConfScore = corridorsCount > 0 ? avgConf / corridorsCount : 92
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricBox(title: "🔗 Ланцюжки Маркова", value: "\(chainsCount)", subtitle: "3+ регіони в польоті", color: .purple)
            metricBox(title: "🚀 Пускові хаби РФ", value: "\(hubsCount)", subtitle: "Моніторинг баз", color: .orange)
            metricBox(title: "🗺️ Коридори траєкторій", value: "\(corridorsCount)", subtitle: "Активні вектори", color: .cyan)
            metricBox(title: "👁️ Індекс довіри Palantir", value: "\(avgConfScore)%", subtitle: "Точність синтезу", color: .green)
        }
    }
    
    private func metricBox(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Synthesis Action Banner
    
    private var synthesisActionBanner: some View {
        Button(action: {
            Task {
                await viewModel.triggerPalantirSynthesis()
            }
        }) {
            HStack {
                if viewModel.isSynthesizingPalantir {
                    ProgressView()
                        .tint(.black)
                        .padding(.trailing, 6)
                    Text("Синтез даних Palantir...")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                } else {
                    Image(systemName: "sparkles.tv.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                    Text("🔄 Догенерувати аналітику Palantir (Зберегти в БД)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                }
                Spacer()
            }
            .padding(14)
            .background(
                LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(12)
            .shadow(color: .cyan.opacity(0.3), radius: 6, y: 2)
        }
        .disabled(viewModel.isSynthesizingPalantir)
    }
    
    // MARK: - Multi-Hop Markov Chains Card (NEW v2.5)
    
    private func multiHopChainsCard(_ overview: PalantirOverviewResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "point.filled.topleft.down.curvedto.point.bottomright.up")
                        .foregroundColor(.purple)
                    Text("🔗 Багатокрокові ланцюжки прольоту (Markov Chains)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("\(overview.multihop_chains?.count ?? 0) виявлено")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.purple)
            }
            
            if let chains = overview.multihop_chains, !chains.isEmpty {
                VStack(spacing: 8) {
                    ForEach(chains.prefix(6)) { chain in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(chain.chain)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(chain.occurrences)x")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.2))
                                    .cornerRadius(6)
                            }
                            
                            HStack {
                                ProgressView(value: chain.confidence, total: 1.0)
                                    .tint(.purple)
                                Text("Довіра: \(Int(chain.confidence * 100))%")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            } else {
                Text("Багатокрокові ланцюжки ще формуються на основі історії хвиль.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(14)
    }
    
    // MARK: - Junction Branches Card (NEW v2.5)
    
    private func junctionBranchesCard(_ overview: PalantirOverviewResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.cyan)
                    Text("🔀 Вузли розгалуження та ймовірності вектору")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("\(overview.junction_branches?.count ?? 0) вузлів")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)
            }
            
            if let branches = overview.junction_branches, !branches.isEmpty {
                VStack(spacing: 10) {
                    ForEach(branches.prefix(4)) { j in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("📍 Вузол: \(j.junction_region)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.cyan)
                                Spacer()
                                Text("Переходів: \(j.total_transitions)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            ForEach(j.branches.prefix(3)) { b in
                                HStack {
                                    Text("➔ \(b.target)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                    Spacer()
                                    ProgressView(value: b.probability, total: 1.0)
                                        .tint(b.probability >= 0.5 ? .cyan : .blue)
                                        .frame(width: 70)
                                    Text("\(Int(b.probability * 100))%")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(b.probability >= 0.5 ? .cyan : .blue)
                                        .frame(width: 36, alignment: .trailing)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("Вузли розгалуження аналізуються при накопиченні переходів.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(14)
    }
    
    // MARK: - Air Defense Attrition Card (NEW v2.5)
    
    private func airDefenseAttritionCard(_ overview: PalantirOverviewResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.green)
                    Text("🛡️ Виснаження цілей силами ППО (ТОП Регіони)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("\(overview.air_defense_attrition?.count ?? 0) областей")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.green)
            }
            
            if let attrition = overview.air_defense_attrition, !attrition.isEmpty {
                VStack(spacing: 8) {
                    ForEach(attrition.prefix(6)) { att in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(att.region)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Збито: \(att.intercepted_count) • Влучання: \(att.impact_count) • Транзит: \(att.transit_count)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(att.interception_rate_percent, specifier: "%.1f")%")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(att.interception_rate_percent >= 70 ? .green : (att.interception_rate_percent >= 40 ? .yellow : .orange))
                                
                                Text(densityLabel(att.defense_density))
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(densityColor(att.defense_density).opacity(0.2))
                                    .foregroundColor(densityColor(att.defense_density))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(6)
                    }
                }
            } else {
                Text("Дані про перехоплення формуються після верифікації відбоїв.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(14)
    }
    
    // MARK: - Trajectory Vectors Card
    
    private func trajectoryVectorsCard(_ overview: PalantirOverviewResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("✈️ Вектори Траєкторій Прольоту")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(overview.trajectory_corridors?.count ?? 0) маршрутів")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan)
            }
            
            if let corridors = overview.trajectory_corridors, !corridors.isEmpty {
                VStack(spacing: 8) {
                    ForEach(corridors.prefix(6)) { corridor in
                        HStack(spacing: 10) {
                            Text(threatIcon(corridor.threat_type))
                                .font(.system(size: 14))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(corridor.source ?? "—") → \(corridor.target ?? "—")")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Тип: \(corridor.threat_type ?? "Загроза") • Вектор: \(corridor.computedSourceLat, specifier: "%.1f"),\(corridor.computedSourceLon, specifier: "%.1f")")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(corridor.count ?? 0)x")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.orange)
                                Text("\(corridor.avg_confidence ?? 90)% довіра")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("Немає активних векторів траєкторій за обраний період.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(14)
    }
    
    // MARK: - Launch Hubs Card
    
    private func launchHubsCard(_ overview: PalantirOverviewResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🚀 Пускові Хаби Ворога (Бази)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(overview.launch_hubs?.count ?? 0) хабів")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
            }
            
            if let hubs = overview.launch_hubs, !hubs.isEmpty {
                VStack(spacing: 8) {
                    ForEach(hubs.prefix(6)) { hub in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hub.name ?? "Хаб")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.orange)
                                Text("Координати: \(hub.lat ?? 0.0, specifier: "%.2f"), \(hub.lon ?? 0.0, specifier: "%.2f")")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            Spacer()
                            Text("\(hub.total_launches ?? 0) пусків")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.15))
                                .cornerRadius(6)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("Пускові хаби не виявлені.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(14)
    }
    
    // MARK: - Regional Risk Card
    
    private func regionalRiskCard(_ overview: PalantirOverviewResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎯 Матриця Загрози по Областях (ТОП-6)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            
            if let regions = overview.region_risk_matrix, !regions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(regions.prefix(6)) { reg in
                        HStack {
                            Text(reg.name ?? "Область")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            
                            ProgressView(value: Double(reg.risk_score ?? 50), total: 100)
                                .tint(riskColor(reg.risk_score ?? 50))
                                .frame(width: 80)
                            
                            Text("\(reg.risk_score ?? 0)%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(riskColor(reg.risk_score ?? 50))
                                .frame(width: 38, alignment: .trailing)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding(14)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(14)
    }
    
    // MARK: - Reports Log Card
    
    private var palantirReportsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📋 Історія Аналітичних Звітів Palantir (БД)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(viewModel.palantirReportsList.count) записів")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.green)
            }
            
            if !viewModel.palantirReportsList.isEmpty {
                VStack(spacing: 8) {
                    ForEach(viewModel.palantirReportsList.prefix(5)) { report in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("📋 \(report.report_date)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.cyan)
                                Spacer()
                                Text("Індекс: \(Int((report.confidence_index ?? 0.95) * 100))%")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                            if let text = report.threat_assessment_summary {
                                Text(text)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(3)
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("Збережених звітів у Palantir БД ще немає. Натисніть кнопку для синтезу.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(14)
    }
    
    // MARK: - Helpers
    
    private func threatIcon(_ type: String?) -> String {
        return ThreatConstants.emoji(for: type)
    }
    
    private func riskColor(_ score: Int) -> Color {
        if score > 70 { return .red }
        if score > 40 { return .orange }
        if score > 20 { return .yellow }
        return .green
    }
    
    private func densityColor(_ density: String) -> Color {
        switch density {
        case "high": return .green
        case "medium": return .cyan
        default: return .yellow
        }
    }
    
    private func densityLabel(_ density: String) -> String {
        switch density {
        case "high": return "Щільне ППО"
        case "medium": return "Середнє ППО"
        default: return "Базове ППО"
        }
    }
}

