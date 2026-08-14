import SwiftUI
import MapKit
#if canImport(UIKit)
import UIKit
#endif

struct BottomDashboardV4: View {
    let activeAlerts: Int
    let primaryRegionName: String?
    @State private var isPulsating = false
    let isSearchingShelter: Bool
    @Binding var transportType: MKDirectionsTransportType
    var onFindShelter: () -> Void
    var onShare: () -> Void
    var onStatusTap: () -> Void

    let threatConfidence: Int?

    private var hasActiveAlert: Bool {
        activeAlerts > 0
    }
    
    private var statusColor: Color {
        hasActiveAlert ? Color(red: 1.0, green: 0.25, blue: 0.25) : Color(red: 0.20, green: 0.85, blue: 0.45)
    }
    
    private var statusTitle: String {
        hasActiveAlert ? "ПОВІТРЯНА ТРИВОГА" : "ТРИВОГ НЕМАЄ"
    }
    
    private var detailText: String {
        hasActiveAlert ? "Активно: \(activeAlerts)" : "Безпечно"
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // ЛІВА ЧАСТИНА: Статус загрози, Регіон та ШІ-Концентрація
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    // Пульсуючий індикатор статусу
                    ZStack {
                        if hasActiveAlert {
                            Circle()
                                .fill(statusColor.opacity(0.35))
                                .frame(width: 16, height: 16)
                                .scaleEffect(isPulsating ? 1.35 : 0.85)
                        }
                        Circle()
                            .fill(statusColor)
                            .frame(width: 9, height: 9)
                            .shadow(color: statusColor.opacity(0.9), radius: 5)
                    }
                    .frame(width: 16, height: 16)
                    
                    Text(statusTitle)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    if let conf = threatConfidence {
                        HStack(spacing: 3) {
                            Image(systemName: "cpu")
                                .font(.system(size: 9, weight: .bold))
                            Text("\(conf)%")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(conf >= 85 ? .red : (conf >= 60 ? .orange : .cyan))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background((conf >= 85 ? Color.red : (conf >= 60 ? Color.orange : Color.cyan)).opacity(0.20))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke((conf >= 85 ? Color.red : (conf >= 60 ? Color.orange : Color.cyan)).opacity(0.4), lineWidth: 0.8)
                        )
                    }
                }
                
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.cyan)
                        Text(primaryRegionName ?? "Україна")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(detailText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(hasActiveAlert ? Color.red.opacity(0.95) : Color.green.opacity(0.95))
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                #if os(iOS)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
                onStatusTap()
            }
            
            Spacer(minLength: 4)
            
            // ПРАВА ЧАСТИНА: Збільшені та покращені ергономічні кнопки
            HStack(spacing: 8) {
                // Перемикач транспорту (Пішки / Авто) зі збільшеним розміром
                HStack(spacing: 2) {
                    transportButton(icon: "figure.walk", mode: .walking)
                    transportButton(icon: "car.fill", mode: .automobile)
                }
                .padding(3)
                .background(Color.black.opacity(0.35))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.16), lineWidth: 0.9)
                )

                // Кнопка "Поділитися" зі збільшеним тачем (38x38pt)
                Button(action: {
                    #if os(iOS)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    #endif
                    onShare()
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.95))
                        .frame(width: 38, height: 38)
                        .background(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.35), Color.cyan.opacity(0.20)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.0
                            )
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())

                // Головна кнопка "ЗНАЙТИ УКРИТТЯ" (збільшена до 44pt з яскравим світінням)
                Button(action: {
                    #if os(iOS)
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    #endif
                    onFindShelter()
                }) {
                    HStack(spacing: 6) {
                        if isSearchingShelter {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.80)
                        } else {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(.cyan)
                        }
                        
                        Text(isSearchingShelter ? "ШУКАЮ..." : "УКРИТТЯ")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.55, blue: 0.95).opacity(0.55),
                                Color(red: 0.10, green: 0.35, blue: 0.85).opacity(0.40)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.85), Color.blue.opacity(0.45)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: Color.cyan.opacity(0.4), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isSearchingShelter)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .background(
            Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.68)
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.cyan.opacity(0.25),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .padding(.horizontal, 12)
        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 5)
        .shadow(color: Color.cyan.opacity(0.12), radius: 16, x: 0, y: 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isPulsating = true
            }
        }
    }

    @ViewBuilder
    private func transportButton(icon: String, mode: MKDirectionsTransportType) -> some View {
        let isSelected = transportType == mode
        Button(action: {
            #if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                transportType = mode
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : .white.opacity(0.55))
                .frame(width: 32, height: 32)
                .background(
                    isSelected
                        ? Color.cyan.opacity(0.35)
                        : Color.clear
                )
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(isSelected ? Color.cyan.opacity(0.6) : Color.clear, lineWidth: 1.0)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
