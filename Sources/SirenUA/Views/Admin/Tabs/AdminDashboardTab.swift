import SwiftUI
import Charts

struct AdminDashboardTab: View {
    @ObservedObject var viewModel: AdminViewModel
    
    var body: some View {
        VStack(spacing: 14) {
            if let d = viewModel.dashboardStats {
                ScrollView {
                    VStack(spacing: 14) {
                        // Stat grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            statBox(title: "📈 Подій (7д)", value: "\(d.total_events_7d)", color: ChartColorTheme.accent)
                            statBox(title: "🎯 Точність AI", value: "\(Int(d.accuracy_pct))%", color: ChartColorTheme.confirmed)
                            statBox(title: "⚡ Активних зараз", value: "\(d.active_now)", color: ChartColorTheme.active)
                            statBox(title: "⏱️ Випередження AI", value: d.avg_early_seconds != nil ? viewModel.formatDuration(d.avg_early_seconds!) : "—", color: ChartColorTheme.cyan)
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
                    }
                }
            } else {
                Text("Не вдалося завантажити статистику.")
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 40)
            }
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
                .font(.system(size: 11))
        }
    }
}
