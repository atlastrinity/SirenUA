import SwiftUI
import MapKit
import OSLog

@available(iOS 16.0, *)
struct AlertRegionDetailView: View {
    let region: AlertRegion
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmed = false
    @State private var isPulsing = false
    
    private var isThreatActive: Bool {
        !region.isActive && region.threatLevel != nil
    }
    
    private var statusTitle: String {
        if region.isActive {
            return "АКТИВНА ТРИВОГА"
        } else if isThreatActive {
            return "Є ЗАГРОЗА (PREMIUM)"
        } else {
            return "ТРИВОГУ СКАСОВАНО"
        }
    }
    
    private var themeColor: Color {
        if region.isActive {
            return .red
        } else if isThreatActive {
            return .yellow
        } else {
            return .green
        }
    }
    
    /// Emoji icon for the current threat type
    private var threatTypeEmoji: String {
        switch region.threatType {
        case "shahed": return "🛩"
        case "cruise_missile": return "🚀"
        case "ballistic": return "💥"
        case "mig31k": return "✈️"
        case "kab": return "💣"
        case "iskander": return "🎯"
        case "tu95": return "✈️"
        default: return "⚠️"
        }
    }

    var body: some View {
        ZStack {
            // Dark glassmorphism background
            Color(red: 0.06, green: 0.06, blue: 0.10)
                .ignoresSafeArea()

            RadialGradient(
                colors: [themeColor.opacity(0.08), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header status card
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(themeColor.opacity(0.15))
                                .frame(width: 46, height: 46)
                                .scaleEffect(isPulsing && (region.isActive || isThreatActive) ? 1.15 : 1.0)
                                .opacity(isPulsing && (region.isActive || isThreatActive) ? 0.6 : 1.0)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
                            Image(systemName: region.isActive ? "exclamationmark.triangle.fill" : (isThreatActive ? "bell.badge.fill" : "checkmark.circle.fill"))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(themeColor)
                        }
                        .shadow(color: themeColor.opacity(0.4), radius: 8)
                        .onAppear { isPulsing = true }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(statusTitle)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(themeColor)

                            if let changed = region.lastChanged {
                                Text(changed)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .background(themeColor.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    colors: [themeColor.opacity(0.4), themeColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: themeColor.opacity(0.15), radius: 12)

                    // Region name with glassmorphism
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(themeColor)
                                .font(.system(size: 14))
                            Text("Область")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Text(region.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(themeColor)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [themeColor.opacity(0.25), themeColor.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                    // Alert/Threat level badge
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(themeColor)
                                .font(.system(size: 14))
                            Text(isThreatActive ? "Рівень загрози" : "Рівень тривоги")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            if isThreatActive {
                                Text(threatTypeEmoji)
                                    .font(.system(size: 18))
                            }
                            Text(isThreatActive ? "Загроза: \(region.threatLevel?.uppercased() ?? "LOW")" : "Рівень \(region.level)")
                                .font(.system(size: 16, weight: .bold))
                        }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(themeColor.opacity(0.12))
                            .foregroundStyle(themeColor)
                            .cornerRadius(12)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [themeColor.opacity(0.2), themeColor.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                    // Threat Detail (from Telegram bot)
                    if let detail = region.threatDetail {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundStyle(themeColor)
                                    .font(.system(size: 14))
                                Text("Що відомо")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }

                            Text(detail)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineSpacing(4)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(radius: 15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [themeColor.opacity(0.2), themeColor.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                    
                    // AI Confidence & ETA Section (Premium threat intelligence)
                    if let confidence = region.threatConfidence {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "cpu.fill")
                                    .foregroundStyle(themeColor)
                                    .font(.system(size: 14))
                                Text("ШІ-аналіз загрози")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 20) {
                                // Circular confidence ring
                                ZStack {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                                        .frame(width: 70, height: 70)
                                    
                                    Circle()
                                        .trim(from: 0, to: CGFloat(confidence) / 100.0)
                                        .stroke(
                                            confidenceColor(confidence),
                                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                        )
                                        .frame(width: 70, height: 70)
                                        .rotationEffect(.degrees(-90))
                                    
                                    VStack(spacing: 1) {
                                        Text("\(confidence)%")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundStyle(confidenceColor(confidence))
                                        Text("довіра")
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    // Confidence label
                                    Text(confidenceLabel(confidence))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(confidenceColor(confidence))
                                    
                                    // ETA badge
                                    if let eta = region.threatETA, !eta.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "clock.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.orange)
                                            Text("Очікуваний час: \(eta)")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.8))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.orange.opacity(0.15))
                                        .cornerRadius(8)
                                    }
                                    
                                    // Predictive flag
                                    if region.isThreatPredictive {
                                        HStack(spacing: 4) {
                                            Image(systemName: "wand.and.stars")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.purple)
                                            Text("Предиктивний аналіз")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(.purple)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(radius: 15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [themeColor.opacity(0.3), themeColor.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }

                    // Warning message (if active alert or active threat)
                    if (region.isActive || isThreatActive) && !isConfirmed {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(themeColor)

                                Text(region.isActive ? "⚠️ Тривога!" : "⚠️ Попередження")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(themeColor)
                            }

                            Text(region.isActive ? 
                                 "У цій області оголошено повітряну тривогу. Негайно прямуйте в укриття!" : 
                                 "Виявлено загрозу початку повітряної тривоги (пуск ракет/рух БПЛА). Будьте готові прослідувати в безпечне місце.")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)

                            // Action buttons for warning
                            HStack(spacing: 12) {
                                Button(action: {
                                    isConfirmed = true
                                }) {
                                    Text(region.isActive ? "Я в безпеці" : "Зрозуміло")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(themeColor)
                                        .foregroundStyle(.black)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                        .background(themeColor.opacity(0.1))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(themeColor.opacity(0.3), lineWidth: 1)
                        )
                    }

                    // History button (Premium)
                    NavigationLink(destination: RegionHistoryView(regionName: region.name, themeColor: themeColor)) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(themeColor.opacity(0.12))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(themeColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Хронологія подій")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("Переглянути історію загроз")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    LinearGradient(
                                        colors: [themeColor.opacity(0.2), themeColor.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .background(Color.clear)
            .navigationTitle(region.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        } // ZStack
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }
    
    private func confidenceColor(_ confidence: Int) -> Color {
        if confidence >= 85 { return .red }
        if confidence >= 60 { return .orange }
        return .yellow
    }
    
    private func confidenceLabel(_ confidence: Int) -> String {
        if confidence >= 85 { return "Висока ймовірність" }
        if confidence >= 60 { return "Ймовірна загроза" }
        return "Можлива загроза"
    }
}


@available(iOS 16.0, *)
struct AlertRegionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        AlertRegionDetailView(
            region: AlertRegion(
                id: 1,
                name: "Київська область",
                isActive: true,
                level: 4,
                description: "Test alert simulation",
                coordinate: CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)
            )
        )
    }
}
