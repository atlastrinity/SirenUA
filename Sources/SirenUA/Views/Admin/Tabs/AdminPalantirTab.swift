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
            
            Text("Автономне трекування траєкторій, пускових хабів ворога та оцінка ризиків")
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
        let corridorsCount = overview.trajectory_corridors?.count ?? 0
        let hubsCount = overview.launch_hubs?.count ?? 0
        let riskRegionsCount = overview.region_risk_matrix?.count ?? 0
        let avgConf = overview.trajectory_corridors?.compactMap { $0.avg_confidence }.reduce(0, +) ?? 0
        let avgConfScore = corridorsCount > 0 ? avgConf / corridorsCount : 92
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricBox(title: "🗺️ Коридори траєкторій", value: "\(corridorsCount)", subtitle: "Активні вектори", color: .cyan)
            metricBox(title: "🚀 Пускові хаби РФ", value: "\(hubsCount)", subtitle: "Моніторинг локацій", color: .orange)
            metricBox(title: "🎯 Зони ризику", value: "\(riskRegionsCount)", subtitle: "Областей в матриці", color: .red)
            metricBox(title: "👁️ Точність Palantir", value: "\(avgConfScore)%", subtitle: "AI індекс довіри", color: .green)
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
                    ForEach(corridors.prefix(8)) { corridor in
                        HStack(spacing: 10) {
                            Text(threatIcon(corridor.threat_type))
                                .font(.system(size: 14))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(corridor.source) → \(corridor.target)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Тип: \(corridor.threat_type ?? "Загроза") • Вектор: \(corridor.source_lat, specifier: "%.1f"),\(corridor.source_lon, specifier: "%.1f")")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(corridor.count)x")
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
                                Text(hub.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.orange)
                                Text("Координати: \(hub.lat, specifier: "%.2f"), \(hub.lon, specifier: "%.2f")")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            Spacer()
                            Text("\(hub.total_launches) пусків")
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
                            Text(reg.name)
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
                Text("Збережених звітів у Palantir БД ще немає. Натисніть кнопкy для синтезу.")
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
        guard let type = type else { return "⚠️" }
        if type.contains("shahed") { return "✈️" }
        if type.contains("ballistic") || type.contains("iskander") { return "🚀" }
        if type.contains("cruise") || type.contains("tu95") { return "🚀" }
        if type.contains("kab") { return "💣" }
        return "⚡"
    }
    
    private func riskColor(_ score: Int) -> Color {
        if score > 70 { return .red }
        if score > 40 { return .orange }
        if score > 20 { return .yellow }
        return .green
    }
}
