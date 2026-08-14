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
    var onSettings: () -> Void
    var onHistory: () -> Void
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
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .opacity(circleOpacity)
                    
                    Text(statusTitle)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    if let conf = threatConfidence {
                        HStack(spacing: 2) {
                            Image(systemName: "cpu")
                                .font(.system(size: 8, weight: .bold))
                            Text("\(conf)%")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(conf >= 85 ? .red : (conf >= 60 ? .orange : .yellow))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background((conf >= 85 ? Color.red : (conf >= 60 ? Color.orange : Color.yellow)).opacity(0.25))
                        .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 5) {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.cyan)
                        Text(primaryRegionName ?? "Україна")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text(detailText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(hasActiveAlert ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }

                // Кнопка Укриття (скло-пілл з чітким текстом)
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
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.cyan)
                        }
                        
                        Text(isSearchingShelter ? "ШУКАЮ..." : "УКРИТТЯ")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 9)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.28),
                                Color.blue.opacity(0.18)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.cyan.opacity(0.45), lineWidth: 0.8)
                    )
                }
                .disabled(isSearchingShelter)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.25)
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.20), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .padding(.horizontal, 10)
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isPulsating = true
            }
        }
    }
}
