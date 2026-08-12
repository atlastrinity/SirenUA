import SwiftUI

enum OverlayFilterMode {
    case activeOnly
    case last24Hours
    case all
}

struct AlertListOverlayView: View {
    let title: String
    let color: Color
    let alerts: [AlertRegion]
    var filterMode: OverlayFilterMode = .last24Hours
    var filterActiveOnly: Bool = false
    let isPremium: Bool
    var onSelect: ((AlertRegion) -> Void)? = nil
    var onClose: () -> Void

    private var effectiveFilterMode: OverlayFilterMode {
        if filterActiveOnly {
            return .activeOnly
        }
        return filterMode
    }

    private var sortedAlerts: [AlertRegion] {
        let baseAlerts = alerts.filter { !RegionRegistry.isPermanentlyActive($0.name) }
        let filtered: [AlertRegion]
        switch effectiveFilterMode {
        case .activeOnly:
            filtered = baseAlerts.filter { $0.isActive || (isPremium && $0.threatLevel != nil) }
        case .last24Hours:
            filtered = baseAlerts.filter { region in
                // 1. Currently active alert or threat zone
                if region.isActive || (isPremium && region.threatLevel != nil) {
                    return true
                }
                // 2. Has active threats registered
                if !region.activeThreats.isEmpty {
                    return true
                }
                // 3. Changed within last 24 hours
                if isWithinLast24Hours(region.lastChanged) {
                    return true
                }
                return false
            }
        case .all:
            filtered = baseAlerts
        }

        return filtered.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive }
            if (a.threatLevel != nil) != (b.threatLevel != nil) { return a.threatLevel != nil }
            return (a.lastChanged ?? "") > (b.lastChanged ?? "")
        }
    }

    private static let dateFormatters: [DateFormatter] = {
        ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "HH:mm"].map { format in
            let f = DateFormatter()
            f.dateFormat = format
            f.timeZone = TimeZone(identifier: "Europe/Kiev")
            return f
        }
    }()

    private func isWithinLast24Hours(_ dateString: String?) -> Bool {
        guard let str = dateString, !str.isEmpty else { return false }
        
        for f in Self.dateFormatters {
            if f.dateFormat == "HH:mm" {
                if f.date(from: str) != nil {
                    return true // HH:mm is today's time
                }
            } else if let date = f.date(from: str) {
                return Date().timeIntervalSince(date) <= 86400
            }
        }
        
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.25))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: color.opacity(0.4), radius: 8)
                    Text(effectiveFilterMode == .last24Hours ? "\(sortedAlerts.count) подій за сутку (24 год)" : "\(sortedAlerts.count) регіонів")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }

                Spacer()

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onClose()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)

            // Separator
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 22)

            // List or Empty View
            if sortedAlerts.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Немає подій за останню сутку")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text("За останні 24 години повітряних тривог чи загроз не зафіксовано.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(sortedAlerts) { alert in
                            alertRow(alert)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.14, blue: 0.32).opacity(0.96),
                    Color(red: 0.02, green: 0.07, blue: 0.22).opacity(0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.ultraThinMaterial)
    }

    private func alertRow(_ alert: AlertRegion) -> some View {
        let isThreat = !alert.isActive && alert.threatLevel != nil
        let rowColor = alert.isActive ? color : (isThreat ? alert.color : Color.gray)
        
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect?(alert)
        }) {
            HStack(alignment: .center, spacing: 14) {
                // Status dot with optional glow
                ZStack {
                    if alert.isActive || isThreat {
                        Circle()
                            .fill(rowColor.opacity(0.3))
                            .frame(width: 18, height: 18)
                    }
                    Circle()
                        .fill(rowColor)
                        .frame(width: 9, height: 9)
                        .shadow(color: (alert.isActive || isThreat) ? rowColor.opacity(0.8) : .clear, radius: 4)
                }
                .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(alert.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 6) {
                        Text(alert.isActive ? "АКТИВНА" : (isThreat ? "ЗАГРОЗА" : "НЕАКТИВНА"))
                            .font(.system(size: 9, weight: .black))
                            .tracking(0.8)
                            .foregroundColor(rowColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(rowColor.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(rowColor.opacity(0.2), lineWidth: 1)
                            )

                        if let changed = alert.lastChanged {
                            Text(changed)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                    
                    // Display threat details
                    if let type = alert.threatType, let detail = alert.threatDetail {
                        Text("⚠️ \(type.uppercased()): \(detail)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(rowColor.opacity(0.8))
                            .multilineTextAlignment(.leading)
                            .padding(.top, 2)
                    }
                    
                    // AI confidence & ETA badge
                    if isThreat || alert.isActive {
                        HStack(spacing: 8) {
                            if let conf = alert.threatConfidence {
                                HStack(spacing: 3) {
                                    Image(systemName: "cpu")
                                        .font(.system(size: 8))
                                    Text("\(conf)%")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(conf >= 85 ? .red : (conf >= 60 ? .orange : .yellow))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background((conf >= 85 ? Color.red : (conf >= 60 ? Color.orange : Color.yellow)).opacity(0.1))
                                .clipShape(Capsule())
                            }
                            if let eta = alert.displayETA, !eta.isEmpty {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 8))
                                    Text(eta)
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(.orange.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.08))
                                .clipShape(Capsule())
                            }
                            if alert.isThreatPredictive {
                                HStack(spacing: 3) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 8))
                                    Text("ШІ")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundColor(.purple.opacity(0.8))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.08))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.17, blue: 0.36).opacity(0.70),
                        Color(red: 0.03, green: 0.09, blue: 0.24).opacity(0.80)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.35), Color.blue.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
