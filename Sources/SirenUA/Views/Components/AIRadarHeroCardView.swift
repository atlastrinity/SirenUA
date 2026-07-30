import SwiftUI

struct AIRadarHeroCardView: View {
    let primaryRegionLabel: String
    let activeThreatCount: Int
    let isAlarmActive: Bool
    let threatDetail: String?
    let threatType: String?
    let confidence: Int?
    let eta: String?
    let isTrackedOnly: Bool
    let allRegionsList: [String]
    let trackedRegionsSet: Set<String>
    let allRegionsTracked: Bool
    let onSelectAllRegions: () -> Void
    let onToggleRegion: (String) -> Void
    var onCardTap: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            // Top Bar: Brand, Logo & Interactive Region Selection Dropdown Menu
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "dot.radiowaves.up.forward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("SirenUA")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Interactive Region Selection Dropdown Menu
                Menu {
                    Button(action: onSelectAllRegions) {
                        HStack {
                            Text("🌐 Усі області України")
                            if allRegionsTracked {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Divider()
                    
                    ForEach(allRegionsList, id: \.self) { regionName in
                        Button(action: { onToggleRegion(regionName) }) {
                            HStack {
                                Text(regionName)
                                if !allRegionsTracked && trackedRegionsSet.contains(regionName) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isTrackedOnly ? "mappin.circle.fill" : "globe.europe.africa.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isTrackedOnly ? .cyan : .yellow)
                        
                        Text(primaryRegionLabel.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.06, green: 0.16, blue: 0.35).opacity(0.85),
                                Color(red: 0.02, green: 0.08, blue: 0.22).opacity(0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(isTrackedOnly ? Color.cyan.opacity(0.6) : Color.yellow.opacity(0.5), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 16)
            
            // Hero Operational Threat Blue Box
            Button(action: {
                onCardTap?()
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isAlarmActive ? Color.red : (activeThreatCount > 0 ? Color.orange : Color.cyan))
                                .frame(width: 7, height: 7)
                            
                            Text("ШІ-РАДАР • ОПЕРАТИВНИЙ МОНІТОРИНГ")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.cyan, .white],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        
                        Spacer()
                        
                        if let conf = confidence {
                            Text("⚙️ \(conf)%")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Capsule())
                        }
                    }
                    
                    // Operational Info Body
                    if let detail = threatDetail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    } else if isAlarmActive {
                        Text("⚠️ Увага! Оголошено повітряну тривогу у відстежуваних областях. Прямуйте в укриття!")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.yellow)
                            .lineLimit(2)
                    } else {
                        Text("🟢 Обновлення моніторингу: Повітряних загроз у відстежуваних областях не зафіксовано.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                    
                    // Footer ETA and Status Info
                    HStack(spacing: 8) {
                        if let eta = eta, !eta.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.cyan)
                                Text("Час підльоту: \(eta)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        
                        Spacer()
                        
                        Text(activeThreatCount > 0 ? "АКТИВНО: \(activeThreatCount) ЗАГРОЗ" : "ОБЛАСТІ БЕЗ БЕЗПОСЕРЕДНЬОЇ ЗАГРОЗИ")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(activeThreatCount > 0 ? .orange : .cyan.opacity(0.9))
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.16, blue: 0.35).opacity(0.92),
                            Color(red: 0.02, green: 0.08, blue: 0.22).opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.6), Color.blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
        }
    }
}
