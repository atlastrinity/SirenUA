import SwiftUI

struct AdminRulesTab: View {
    @ObservedObject var viewModel: AdminViewModel
    
    var body: some View {
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
                    Picker("", selection: $viewModel.rulesDaysFilter) {
                        Text("7 днів").tag(7)
                        Text("14 днів").tag(14)
                        Text("30 днів").tag(30)
                    }
                    .pickerStyle(.menu)
                }
                
                HStack(spacing: 8) {
                    Picker("Тип правила", selection: $viewModel.rulesTypeFilter) {
                        Text("Всі типи").tag("")
                        Text("Маршрут").tag("route_pattern")
                        Text("Довіра").tag("confidence_correction")
                        Text("Часовий").tag("time_pattern")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    Picker("Загроза", selection: $viewModel.rulesThreatTypeFilter) {
                        Text("Всі типи").tag("")
                        ForEach(ThreatConstants.all.filter { $0 != ThreatConstants.unknown }, id: \.self) { t in
                            Text("\(ThreatConstants.emoji(for: t)) \(ThreatConstants.title(for: t))").tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }
                
                HStack {
                    Picker("Дія аудиту", selection: $viewModel.rulesActionFilter) {
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
                        Task { await viewModel.fetchRules() }
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
            
            // Regional Rule Metrics & Dispersion Analytics Panel
            RegionalRuleMetricsCard(viewModel: viewModel)
            
            // Post-Mortem Deep Reflection Section (NEW v2.5)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .foregroundColor(.pink)
                    Text("🧠 Автономна ШІ-Рефлексія Post-Mortem")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    if viewModel.isTriggeringPostMortem {
                        ProgressView()
                            .tint(.pink)
                    }
                }
                
                Text("Глибинний аналіз завершених сесій через Gemini AI: виявлення патернів прориву, хибних тривог та коригування швидкостей.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(3)
                
                HStack(spacing: 8) {
                    Button(action: {
                        viewModel.triggerHaptic("heavy")
                        Task { await viewModel.triggerPostMortem(hours: 4) }
                    }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Post-Mortem (4 год)")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.pink.opacity(0.3))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pink.opacity(0.6), lineWidth: 1))
                    }
                    .disabled(viewModel.isTriggeringPostMortem)
                    
                    Button(action: {
                        viewModel.triggerHaptic("heavy")
                        Task { await viewModel.triggerPostMortem(hours: 24) }
                    }) {
                        HStack {
                            Image(systemName: "flame.fill")
                            Text("Масований (24 год)")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.3))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.6), lineWidth: 1))
                    }
                    .disabled(viewModel.isTriggeringPostMortem)
                }
                
                if viewModel.showPostMortemSuccess {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text(viewModel.postMortemResultText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)
            
            // AI Learning Engine 5 Mathematical Criteria Visualizer (NEW v2.5)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "function")
                        .foregroundColor(.cyan)
                    Text("📐 5 Математичних критеріїв навчання ШІ")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                VStack(spacing: 6) {
                    learningRuleCriterionRow(icon: "map.fill", title: "Маршрутний вектор", desc: ">= 3 підтверджених прольотів, точність >= 70%", color: .cyan)
                    learningRuleCriterionRow(icon: "shield.righthalf.filled", title: "Корекція довіри", desc: "Зниження ваги при переоцінці (< 50%) або буст (> 80%)", color: .green)
                    learningRuleCriterionRow(icon: "clock.fill", title: "Часові патерни", desc: "Кластеризація хвиль за годинами доби (нічні/ранкові)", color: .orange)
                    learningRuleCriterionRow(icon: "speedometer", title: "Математика ETA", desc: "Коригування швидкостей цілей при дельті > 15 хв", color: .purple)
                    learningRuleCriterionRow(icon: "leaf.arrow.circlepath", title: "Згасання правил (Decay)", desc: "Правила без нових доказів знеструмлюються за 14 днів", color: .gray)
                }
            }
            .padding(12)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)
            
            // Rebuild rules section
            VStack(alignment: .leading, spacing: 12) {
                Text("⚙️ Перебудова правил з paired_events")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Button(action: {
                    viewModel.triggerHaptic()
                    Task { await viewModel.rebuildRules() }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Перебудувати правила з парних подій")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.5), lineWidth: 1))
                }
                
                if viewModel.showRebuildSuccess {
                    Text("✅ Правила успішно перебудовано на сервері!")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.top, 2)
                }
            }
            .padding(12)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)
            
            // Active rules list grouped by region
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Активні правила за областю (\(viewModel.activeRules.count))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    if viewModel.activeRules.isEmpty {
                        Text("Немає активних правил самонавчання.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(viewModel.rulesGroupedByRegion, id: \.0) { regionGroup in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("📍 \(regionGroup.0)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.cyan)
                                    Spacer()
                                    Text("\(regionGroup.1.count) правил(а)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(.top, 4)
                                
                                ForEach(regionGroup.1) { rule in
                                    GeminiRuleRow(rule: rule, viewModel: viewModel)
                                }
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
                            )
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
                    
                    if viewModel.ruleAuditHistory.isEmpty {
                        Text("Аудит-лог правил порожній.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(viewModel.ruleAuditHistory) { entry in
                            GeminiRuleAuditRow(entry: entry, viewModel: viewModel)
                        }
                    }
                }
                .padding(14)
                .background(ChartColorTheme.cardBg)
                .cornerRadius(12)
            }
            .onChange(of: viewModel.rulesDaysFilter) { _, _ in
                Task { await viewModel.fetchRules() }
            }
            .onChange(of: viewModel.rulesTypeFilter) { _, _ in
                Task { await viewModel.fetchRules() }
            }
            .onChange(of: viewModel.rulesThreatTypeFilter) { _, _ in
                Task { await viewModel.fetchRules() }
            }
            .onChange(of: viewModel.rulesActionFilter) { _, _ in
                Task { await viewModel.fetchRules() }
            }
        }
    }
    
    private func learningRuleCriterionRow(icon: String, title: String, desc: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 12))
                .frame(width: 16, height: 16)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(8)
        .background(Color.white.opacity(0.02))
        .cornerRadius(6)
    }
}

struct GeminiRuleRow: View {
    let rule: GeminiRule
    let viewModel: AdminViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ruleTypeBadgeText(rule.rule_type))
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ruleTypeColor(rule.rule_type).opacity(0.2))
                    .foregroundColor(ruleTypeColor(rule.rule_type))
                    .cornerRadius(4)
                
                Spacer()
                
                Text("\(Int(rule.accuracy_score * 100))% точність")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(rule.accuracy_score >= 0.7 ? .green : .yellow)
                
                Text("Доказів: \(rule.evidence_count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text(rule.rule_text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.95))
                .lineLimit(3)
            
            HStack(spacing: 8) {
                if let src = rule.source_region, !src.isEmpty {
                    Text("🗺️ \(src) → \(rule.target_region ?? "")")
                }
                if let th = rule.threat_type, !th.isEmpty {
                    Text("🚀 \(th)")
                }
                Spacer()
                Text(viewModel.formatShortTime(rule.updated_at))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
            }
            .font(.system(size: 10))
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(10)
        .background(Color.white.opacity(0.02))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ruleTypeColor(rule.rule_type).opacity(0.25), lineWidth: 1))
    }
    
    private func ruleTypeColor(_ type: String) -> Color {
        switch type {
        case "route_pattern": return .cyan
        case "confidence_correction": return .green
        case "time_pattern": return .orange
        case "eta_math": return .purple
        case "post_mortem": return .pink
        default: return .blue
        }
    }
    
    private func ruleTypeBadgeText(_ type: String) -> String {
        switch type {
        case "route_pattern": return "МАРШРУТ"
        case "confidence_correction": return "ДОВІРА"
        case "time_pattern": return "ЧАС"
        case "eta_math": return "ETA"
        case "post_mortem": return "POST-MORTEM"
        default: return type.uppercased()
        }
    }
}

struct GeminiRuleAuditRow: View {
    let entry: GeminiRuleAuditEntry
    let viewModel: AdminViewModel

    var body: some View {
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
                
                Text(viewModel.formatShortTime(entry.timestamp))
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
                    Text("Маршрут: \(src) → \(entry.target_region ?? "")")
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

// MARK: - Regional Rule Metrics & Dispersion Graph Component

struct RegionalRuleMetricsCard: View {
    @ObservedObject var viewModel: AdminViewModel

    var metrics: AdminRegionRuleMetrics? {
        viewModel.regionalRuleMetrics[viewModel.selectedRuleRegion]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📊 Регіональна аналітика та дисперсія ШІ")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }

            // Region selector picker
            HStack {
                Text("Область:")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Picker("", selection: $viewModel.selectedRuleRegion) {
                    ForEach(viewModel.regionalRuleMetrics.keys.sorted(), id: \.self) { reg in
                        Text(reg).tag(reg)
                    }
                }
                .pickerStyle(.menu)
                .tint(.cyan)
            }

            if let m = metrics {
                // Key metrics row
                HStack(spacing: 8) {
                    MetricBadge(title: "Приріст точності", value: "+\(String(format: "%.1f", m.accuracy_gain_pct))%", color: .green)
                    MetricBadge(title: "Дисперсія дольоту", value: "±\(String(format: "%.1f", m.eta_variance_minutes)) хв", color: .cyan)
                    MetricBadge(title: "Активні правила", value: "\(m.active_rules_count)", color: .purple)
                }

                // Interactive trend chart bar
                VStack(alignment: .leading, spacing: 6) {
                    Text("Динаміка прибутковості точності та зниження дисперсії (8 днів):")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))

                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(m.graph_time_series) { point in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(gradient: Gradient(colors: [Color.green, Color.cyan]), startPoint: .top, endPoint: .bottom))
                                    .frame(height: max(12, CGFloat(point.accuracy_score) * 0.5))
                                Text(String(point.timestamp.suffix(2)))
                                    .font(.system(size: 8))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 60)
                    .padding(.top, 4)
                }
            } else {
                Text("Очікування завантаження аналітики областей...")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.vertical, 8)
            }
        }
        .padding(12)
        .background(ChartColorTheme.cardBg)
        .cornerRadius(12)
    }
}

struct MetricBadge: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

