import SwiftUI
import MapKit

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
