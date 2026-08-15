import SwiftUI
import Charts

struct AdminDashboardTab: View {
    @ObservedObject var viewModel: AdminViewModel
    
    var body: some View {
        VStack(spacing: 14) {
            if let d = viewModel.dashboardStats {
                VStack(spacing: 14) {
                    // Stat grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        statBox(title: "📈 Подій (7д)", value: "\(d.total_events_7d ?? 0)", color: ChartColorTheme.accent)
                        statBox(title: "🎯 Точність AI", value: "\(Int(d.accuracy_pct ?? 0.0))%", color: ChartColorTheme.confirmed)
                        statBox(title: "⚡ Активних зараз", value: "\(d.active_now ?? 0)", color: ChartColorTheme.active)
                        statBox(title: "⏱️ Випередження AI", value: d.avg_early_seconds != nil ? viewModel.formatDuration(d.avg_early_seconds!) : "—", color: ChartColorTheme.cyan)
                    }
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        statBox(title: "✅ Підтверджено", value: "\(d.accuracy?.confirmed ?? 0)", color: ChartColorTheme.confirmed)
                        statBox(title: "🛡️ Збито/РЕБ", value: "\(d.accuracy?.mitigated ?? 0)", color: ChartColorTheme.mitigated)
                        statBox(title: "❌ Помилкові", value: "\(d.accuracy?.overestimated ?? 0)", color: ChartColorTheme.overestimated)
                        if let cleared = d.accuracy?.cleared, cleared > 0 {
                            statBox(title: "🔄 Інші / Знято", value: "\(cleared)", color: ChartColorTheme.cleared)
                        } else {
                            statBox(title: "🔴 Помилки (24г)", value: "\(d.errors_24h ?? 0)", color: ChartColorTheme.orange)
                        }
                    }
                    
                    // Accuracy sector map
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🎯 Результати аналізу AI")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Chart {
                            SectorMark(angle: .value("Count", d.accuracy?.confirmed ?? 0), innerRadius: .ratio(0.6), angularInset: 1.5)
                                .foregroundStyle(ChartColorTheme.confirmed)
                                .annotation(position: .overlay) {
                                    if (d.accuracy?.confirmed ?? 0) > 0 {
                                        Text("\(d.accuracy?.confirmed ?? 0)").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                    }
                                }
                            SectorMark(angle: .value("Count", d.accuracy?.mitigated ?? 0), innerRadius: .ratio(0.6), angularInset: 1.5)
                                .foregroundStyle(ChartColorTheme.mitigated)
                                .annotation(position: .overlay) {
                                    if (d.accuracy?.mitigated ?? 0) > 0 {
                                        Text("\(d.accuracy?.mitigated ?? 0)").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                    }
                                }
                            SectorMark(angle: .value("Count", d.accuracy?.overestimated ?? 0), innerRadius: .ratio(0.6), angularInset: 1.5)
                                .foregroundStyle(ChartColorTheme.overestimated)
                                .annotation(position: .overlay) {
                                    if (d.accuracy?.overestimated ?? 0) > 0 {
                                        Text("\(d.accuracy?.overestimated ?? 0)").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                    }
                                }
                            SectorMark(angle: .value("Count", d.accuracy?.active ?? 0), innerRadius: .ratio(0.6), angularInset: 1.5)
                                .foregroundStyle(ChartColorTheme.active)
                            if let cleared = d.accuracy?.cleared, cleared > 0 {
                                SectorMark(angle: .value("Count", cleared), innerRadius: .ratio(0.6), angularInset: 1.5)
                                    .foregroundStyle(ChartColorTheme.cleared)
                            }
                        }
                        .frame(height: 140)
                        
                        HStack(spacing: 12) {
                            legendItem(title: "Підтв.", color: ChartColorTheme.confirmed)
                            legendItem(title: "Збито", color: ChartColorTheme.mitigated)
                            legendItem(title: "Помилк.", color: ChartColorTheme.overestimated)
                            legendItem(title: "Актив.", color: ChartColorTheme.active)
                            if (d.accuracy?.cleared ?? 0) > 0 {
                                legendItem(title: "Знято", color: ChartColorTheme.cleared)
                            }
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
                            ForEach(d.by_type ?? []) { item in
                                BarMark(
                                    x: .value("Кількість", item.count),
                                    y: .value("Тип", item.threat_type)
                                )
                                .foregroundStyle(ChartColorTheme.accent)
                                .cornerRadius(4)
                            }
                        }
                        .frame(height: CGFloat(max(80, (d.by_type?.count ?? 0) * 25)))
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
                            ForEach(d.top_regions ?? []) { item in
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
                            ForEach(d.hourly ?? []) { item in
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
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 36))
                        .foregroundColor(.blue.opacity(0.8))
                    
                    VStack(spacing: 4) {
                        Text("Підключення до адмін-сервера...")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text("Сервер пробуджується або оновлює аналітику ШІ.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        Task { await viewModel.refreshAllData() }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Оновити аналітику")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(ChartColorTheme.cardBg)
                .cornerRadius(14)
                .padding(.top, 20)
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
