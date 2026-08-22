import SwiftUI
import MapKit

struct RegionStatusBadgeAnnotation: MapContent {
    let alert: AlertRegion
    let timeRefreshTrigger: Date
    var zoomScale: CGFloat = 1.0
    var isPremium: Bool = false
    let onRegionSelected: (AlertRegion) -> Void

    var body: some MapContent {
        if RegionRegistry.isPermanentlyActive(alert.name) {
            Annotation(coordinate: alert.coordinate) {
                VStack(spacing: 1) {
                    Text(alert.name)
                        .font(.system(size: isPremium ? 9 : 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .scaleEffect(zoomScale)
            } label: {
                EmptyView()
            }
        } else {
            let isThreatActive = !alert.isActive && alert.threatLevel != nil
            let badgeIcon: String = alert.isActive ? "exclamationmark.triangle.fill" : (isThreatActive ? alert.icon : "checkmark.circle.fill")
            let badgeBgColor: Color = alert.isActive ? .red : (isThreatActive ? alert.color : .green)

            Annotation(coordinate: alert.coordinate) {
                VStack(alignment: .center, spacing: 4) {
                    if isPremium {
                        Image(systemName: badgeIcon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(badgeBgColor)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                            .shadow(radius: 3)
                    }

                    VStack(spacing: 1) {
                        let _ = timeRefreshTrigger
                        Text(alert.name)
                            .font(.system(size: isPremium ? 9 : 10, weight: .bold))
                            .foregroundColor(.white)

                        if alert.isActive && !alert.activeDistricts.isEmpty {
                            let districtsText = alert.activeDistricts.count <= 2
                                ? alert.activeDistricts.joined(separator: ", ")
                                : "\(alert.activeDistricts[0]) +\(alert.activeDistricts.count - 1)"
                            Text("📍 " + districtsText)
                                .font(.system(size: 7.5, weight: .semibold))
                                .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                                .lineLimit(1)
                        }

                        if isPremium {
                            if isThreatActive {
                                let type = alert.currentThreat?.type ?? alert.threatType
                                let desc = ThreatConstants.title(for: type)
                                Text(desc.isEmpty || desc == "Загроза" ? "Загроза підльоту" : desc)
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.yellow)
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)
                            }

                            if isThreatActive {
                                HStack(spacing: 3) {
                                    if let conf = alert.threatConfidence {
                                        Text("⚙️ \(conf)%")
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundColor(conf >= 85 ? Color(red: 0.96, green: 0.75, blue: 0.05) : (conf >= 60 ? Color(red: 0.98, green: 0.84, blue: 0.12) : Color(red: 0.98, green: 0.90, blue: 0.35)))
                                    }
                                    if let eta = alert.displayETA, !eta.isEmpty {
                                        Text(eta)
                                            .font(.system(size: 7, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                            } else if !alert.isActive {
                                Text("Без тривоги")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(.green.opacity(0.8))
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .scaleEffect(zoomScale)
                .onTapGesture {
                    onRegionSelected(alert)
                }
            } label: {
                EmptyView()
            }
        }
    }
}
