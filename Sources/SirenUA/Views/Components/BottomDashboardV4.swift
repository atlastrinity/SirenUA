import SwiftUI
import MapKit

struct BottomDashboardV4: View {
    let activeAlerts: Int
    let primaryRegionName: String?
    @State private var isPulsating = false
    let isSearchingShelter: Bool
    @Binding var transportType: MKDirectionsTransportType
    var onFindShelter: () -> Void
    var onShare: () -> Void
    var onSettings: () -> Void
    var onHistory: () -> Void
    var onStatusTap: () -> Void

    private var hasActiveAlert: Bool {
        activeAlerts > 0
    }
    
    private var statusColor: Color {
        hasActiveAlert ? .red : .green
    }
    
    private var circleOpacity: Double {
        hasActiveAlert && isPulsating ? 0.3 : 1.0
    }
    
    private var statusText: String {
        hasActiveAlert ? "ПОВІТРЯНА\nТРИВОГА" : "ТРИВОГ\nНЕМАЄ"
    }
    
    private var detailText: String {
        hasActiveAlert ? "Активних областей: \(activeAlerts)" : "Останні дані оновлено"
    }
    
    private var detailColor: Color {
        hasActiveAlert ? Color.red.opacity(0.8) : Color.green.opacity(0.8)
    }
    
    var body: some View {
        HStack(alignment: .top) {
            // Ліва частина: Статус
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                        .opacity(circleOpacity)
                    
                    Text(statusText)
                        .font(.system(size: 20, weight: .heavy, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryRegionName ?? "Україна")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    Text(detailText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(detailColor)
                }
                .padding(.top, 4)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onStatusTap()
            }
            
            Spacer()
            
            // Права частина: Кнопки
            VStack(alignment: .trailing, spacing: 12) {
                // Транспорт
                Picker("Транспорт", selection: $transportType) {
                    Image(systemName: "figure.walk").tag(MKDirectionsTransportType.walking)
                    Image(systemName: "car").tag(MKDirectionsTransportType.automobile)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                
                // Маленькі іконки дій
                HStack(spacing: 20) {
                    SmallIconButtonV4(iconName: "clock.fill") {
                        onHistory()
                    }
                    SmallIconButtonV4(iconName: "square.and.arrow.up") {
                        onShare()
                    }
                    SmallIconButtonV4(iconName: "gearshape.fill") {
                        onSettings()
                    }
                }
                
                // Головна кнопка "Знайти укриття"
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    onFindShelter()
                }) {
                    HStack(spacing: 8) {
                        if isSearchingShelter {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSearchingShelter ? "ШУКАЮ\nУКРИТТЯ" : "ЗНАЙТИ НАЙБЛИЖЧЕ\nУКРИТТЯ")
                            .font(.system(size: 12, weight: .bold))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.18, green: 0.5, blue: 0.95), Color(red: 0.5, green: 0.3, blue: 0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color(red: 0.18, green: 0.5, blue: 0.95).opacity(isPulsating ? 0.6 : 0.2), radius: isPulsating ? 8 : 4)
                }
                .disabled(isSearchingShelter)
            }
        }
        .padding(20)
        // Ефект надпрозорого преміального скла (Glassmorphism)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.04))
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
        )
        .padding(.horizontal, 16)
        .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isPulsating = true
            }
        }
    }
}
