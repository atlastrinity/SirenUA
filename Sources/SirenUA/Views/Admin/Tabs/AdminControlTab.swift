import SwiftUI

struct AdminControlTab: View {
    @ObservedObject var viewModel: AdminViewModel
    
    var body: some View {
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
                        Picker("", selection: $viewModel.simRegion) {
                            ForEach(viewModel.regionsList, id: \.self) { r in
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
                        Picker("", selection: $viewModel.simLevel) {
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
                        Picker("", selection: $viewModel.simThreatType) {
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
                        TextField("Наприклад: Повідомляють про рух БПЛА...", text: $viewModel.simDetail)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        viewModel.triggerHaptic()
                        Task { await viewModel.injectCustomThreat() }
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
                    
                    if viewModel.showSimSuccessMessage {
                        Text(viewModel.simSuccessText)
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
                    diagnosticsRow(name: "Сервер офіційних тривог", url: "ubilling.net.ua", status: viewModel.alertsStatus)
                    Divider().background(Color.white.opacity(0.06))
                    diagnosticsRow(name: "Сервер аналітики (Premium)", url: "sirenua-threatserver.onrender.com", status: viewModel.threatsStatus)
                    Divider().background(Color.white.opacity(0.06))
                    diagnosticsRow(name: "Аналізатор Gemini API", url: "gemini-3.1-flash-lite", status: viewModel.geminiStatus)
                }
                .padding(.vertical, 4)
                
                Button(action: {
                    viewModel.triggerHaptic()
                    viewModel.alertsStatus = "Перевірка..."
                    viewModel.threatsStatus = "Перевірка..."
                    viewModel.geminiStatus = "Перевірка..."
                    Task { await viewModel.performDiagnostics() }
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
                            viewModel.triggerHaptic()
                            Task { await viewModel.postClearAll() }
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
            viewModel.triggerHaptic()
            Task { await viewModel.postTriggerScenario(scenario) }
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
}
