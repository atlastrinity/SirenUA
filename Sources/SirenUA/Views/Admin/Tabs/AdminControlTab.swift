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
                    
                }
            }
            .padding(14)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)
        }
        .padding(.top, 4)
    }
}
