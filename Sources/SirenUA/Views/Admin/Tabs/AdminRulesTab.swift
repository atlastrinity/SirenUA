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
                    viewModel.triggerHaptic()
                    Task { await viewModel.rebuildRules() }
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
            
            // Active rules list
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Активні правила навчання (\(viewModel.activeRules.count))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        if viewModel.activeRules.isEmpty {
                            Text("Немає активних правил самонавчання.")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .padding(.vertical, 20)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(viewModel.activeRules) { rule in
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
                        
                        if viewModel.ruleAuditHistory.isEmpty {
                            Text("Аудит-лог правил порожній.")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .padding(.vertical, 20)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(viewModel.ruleAuditHistory) { entry in
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
}
