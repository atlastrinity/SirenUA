import SwiftUI
import MapKit
import UIKit

// MARK: - ShelterDetailView

struct ShelterDetailView: View {
    let shelter: MKMapItem
    let route: MKRoute?
    var isCalculatingRoute: Bool
    var routeErrorMessage: String?
    let onRouteRequested: () -> Void
    let onStartNavigation: () -> Void

    private var distanceText: String? {
        guard let route else { return nil }
        let meters = Int(route.distance)
        return meters >= 1000
            ? String(format: "%.1f км", Double(meters) / 1000)
            : "\(meters) м"
    }

    private var timeText: String? {
        guard let route else { return nil }
        let minutes = Int(route.expectedTravelTime / 60)
        if minutes < 60 {
            return "\(minutes) хв"
        } else {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h) год \(m) хв" : "\(h) год"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 16)

            // Header
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "figure.walk.arrival")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.blue)
                }
                .shadow(color: Color.blue.opacity(0.3), radius: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(shelter.name ?? "Невідоме укриття")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if let address = shelter.placemark.title {
                        Text(address)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                }
            }
            .padding(.horizontal, 24)

            // Route info / error
            if let dist = distanceText, let time = timeText {
                HStack(spacing: 16) {
                    routeStatBadge(icon: "ruler", value: dist, color: .blue)
                    routeStatBadge(icon: "clock", value: time, color: .green)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
            } else if let error = routeErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }

            // Action buttons
            HStack(spacing: 12) {
                if route == nil {
                    Button(action: onRouteRequested) {
                        HStack(spacing: 8) {
                            if isCalculatingRoute {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            } else {
                                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Text(isCalculatingRoute ? "Обчислення..." : "Побудувати маршрут")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.20, green: 0.52, blue: 0.98), Color(red: 0.45, green: 0.30, blue: 0.92)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.blue.opacity(0.35), radius: 10, x: 0, y: 5)
                    }
                    .disabled(isCalculatingRoute)
                } else {
                    Button(action: onStartNavigation) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Почати навігацію")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.18, green: 0.80, blue: 0.55), Color(red: 0.10, green: 0.65, blue: 0.40)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.green.opacity(0.35), radius: 10, x: 0, y: 5)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color.clear)
    }

    private func routeStatBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 1))
    }
}

struct AlertListOverlayView: View {
    let title: String
    let color: Color
    let alerts: [AlertRegion]
    let filterActiveOnly: Bool
    let isPremium: Bool
    var onSelect: ((AlertRegion) -> Void)? = nil
    var onClose: () -> Void

    private var sortedAlerts: [AlertRegion] {
        let filtered = filterActiveOnly ? alerts.filter { $0.isActive || (isPremium && $0.threatLevel != nil) } : alerts
        return filtered.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive }
            if (a.threatLevel != nil) != (b.threatLevel != nil) { return a.threatLevel != nil }
            return (a.lastChanged ?? "") > (b.lastChanged ?? "")
        }
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
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: color.opacity(0.4), radius: 8)
                    Text("\(sortedAlerts.count) регіонів")
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

            // List
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.55).ignoresSafeArea())
    }

    private func alertRow(_ alert: AlertRegion) -> some View {
        let isThreat = !alert.isActive && alert.threatLevel != nil
        let rowColor = alert.isActive ? color : (isThreat ? Color.yellow : Color.gray.opacity(0.4))
        
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
                            .foregroundColor(alert.isActive ? color : (isThreat ? .yellow : .gray))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background((alert.isActive ? color : (isThreat ? .yellow : Color.gray)).opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke((alert.isActive ? color : (isThreat ? .yellow : Color.gray)).opacity(0.2), lineWidth: 1)
                            )

                        if let changed = alert.lastChanged {
                            Text(changed)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                    
                    // Display details for premium users
                    if isPremium, let type = alert.threatType, let detail = alert.threatDetail {
                        Text("⚠️ \(type.uppercased()): \(detail)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.yellow.opacity(0.8))
                            .multilineTextAlignment(.leading)
                            .padding(.top, 2)
                    }
                    
                    // AI confidence & ETA badge for premium users
                    if isPremium, isThreat {
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
                            if let eta = alert.threatETA, !eta.isEmpty {
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
                alert.isActive
                    ? color.opacity(0.05)
                    : (isThreat ? Color.yellow.opacity(0.03) : Color.white.opacity(0.02))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        alert.isActive ? color.opacity(0.2) : (isThreat ? Color.yellow.opacity(0.15) : Color.white.opacity(0.05)),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - MKDirectionsTransportType Hashable

extension MKDirectionsTransportType: @retroactive Hashable {}

// MARK: - Press Events Extension

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

// MARK: - NavigationOverlay

struct NavigationOverlay: View {
    let route: MKRoute?
    let onEndNavigation: () -> Void

    private var distanceText: String {
        guard let route else { return "" }
        let meters = Int(route.distance)
        return meters >= 1000 ? String(format: "%.1f км", Double(meters) / 1000) : "\(meters) м"
    }

    private var timeText: String {
        guard let route else { return "" }
        let minutes = Int(route.expectedTravelTime / 60)
        if minutes < 60 {
            return "\(minutes) хв"
        } else {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h) год \(m) хв" : "\(h) год"
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "location.north.line.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Навігація активна")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    if route != nil {
                        HStack(spacing: 8) {
                            Label(distanceText, systemImage: "ruler")
                            Label(timeText, systemImage: "clock")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green.opacity(0.85))
                    }
                }
                Spacer()

                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: .green, radius: 4)
            }

            Button(action: onEndNavigation) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                    Text("Завершити навігацію")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(
                        colors: [Color.red, Color.red.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .preferredColorScheme(.dark)
        .padding(.horizontal, 16)
    }
}
