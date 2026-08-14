import SwiftUI
import MapKit
import UIKit

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
        hasActiveAlert ? .red : .green
    }
    
    private var circleOpacity: Double {
        hasActiveAlert && isPulsating ? 0.3 : 1.0
    }
    
    private var statusTitle: String {
        hasActiveAlert ? "ПОВІТРЯНА ТРИВОГА" : "ТРИВОГ НЕМАЄ"
    }
    
    private var detailText: String {
        hasActiveAlert ? "Активно: \(activeAlerts)" : "Актуально"
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Ліва частина: Статус, Локація та ШІ-Концентрація
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    ZStack {
                        if hasActiveAlert {
                            Circle()
                                .fill(statusColor.opacity(0.35))
                                .frame(width: 14, height: 14)
                                .scaleEffect(isPulsating ? 1.3 : 0.85)
                        }
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: statusColor.opacity(0.8), radius: 4)
                    }
                    .frame(width: 14, height: 14)
                    
                    Text(statusTitle)
                        .font(.system(size: 11, weight: Font.Weight.black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    if let conf = threatConfidence {
                        HStack(spacing: 2) {
                            Image(systemName: "cpu")
                                .font(.system(size: 8, weight: Font.Weight.bold))
                            Text("\(conf)%")
                                .font(.system(size: 8, weight: Font.Weight.bold, design: .monospaced))
                        }
                        .foregroundColor(conf >= 85 ? .red : (conf >= 60 ? .orange : .yellow))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background((conf >= 85 ? Color.red : (conf >= 60 ? Color.orange : Color.yellow)).opacity(0.25))
                        .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 5) {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8, weight: Font.Weight.bold))
                            .foregroundColor(.cyan)
                        Text(primaryRegionName ?? "Україна")
                            .font(.system(size: 10, weight: Font.Weight.bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(detailText)
                        .font(.system(size: 10, weight: Font.Weight.semibold))
                        .foregroundColor(hasActiveAlert ? Color.red.opacity(0.95) : Color.green.opacity(0.95))
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onStatusTap()
            }
            
            Spacer(minLength: 2)
            
            // Права частина: Перемикач транспорту, Поділитися та Кнопка Укриття
            HStack(spacing: 6) {
                // Перемикач транспорту (компактний сегмент)
                Picker("Транспорт", selection: $transportType) {
                    Image(systemName: "figure.walk").tag(MKDirectionsTransportType.walking)
                    Image(systemName: "car").tag(MKDirectionsTransportType.automobile)
                }
                .pickerStyle(.segmented)
                .frame(width: 72)
                .scaleEffect(0.82)

                // Кнопка Поділитися
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11, weight: Font.Weight.semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                }
                .buttonStyle(PlainButtonStyle())

                // Кнопка Укриття (скло-пілл з градієнтом та світінням)
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onFindShelter()
                }) {
                    HStack(spacing: 4) {
                        if isSearchingShelter {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.65)
                        } else {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 11, weight: Font.Weight.bold))
                                .foregroundColor(.cyan)
                        }
                        
                        Text(isSearchingShelter ? "ШУКАЮ..." : "УКРИТТЯ")
                            .font(.system(size: 10, weight: Font.Weight.heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.35),
                                Color.blue.opacity(0.25)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.65), Color.blue.opacity(0.35)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.0
                            )
                    )
                    .shadow(color: Color.cyan.opacity(0.3), radius: 5, x: 0, y: 1)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isSearchingShelter)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(
            Color(red: 0.03, green: 0.07, blue: 0.18).opacity(0.40)
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            Color.cyan.opacity(0.18),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        )
        .padding(.horizontal, 12)
        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isPulsating = true
            }
        }
    }
}
