import SwiftUI
import MapKit
#if canImport(UIKit)
import UIKit
#endif

struct ShelterDetailView: View {
    let shelter: MKMapItem
    let route: MKRoute?
    var isCalculatingRoute: Bool
    var routeErrorMessage: String?
    let onRouteRequested: () -> Void
    let onStartNavigation: () -> Void

    private var shelterIcon: String {
        ShelterType.iconName(for: shelter.name ?? "")
    }

    private var distanceText: String? {
        guard let route else { return nil }
        return ShelterFormatter.formatDistance(meters: route.distance)
    }

    private var timeText: String? {
        guard let route else { return nil }
        return ShelterFormatter.formatTravelTime(seconds: route.expectedTravelTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.35))
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 18)

            // Header
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.25), Color.blue.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(Circle().stroke(Color.cyan.opacity(0.35), lineWidth: 1))
                    Image(systemName: shelterIcon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.cyan)
                }
                .shadow(color: Color.cyan.opacity(0.35), radius: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(shelter.name ?? "Укриття цивільного захисту")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if let address = shelter.placemark.title {
                        Text(address)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(2)
                    }
                }
            }
            .padding(.horizontal, 24)

            // Status & Feature Badges (Category, Night 24/7 Access, Vehicle Parking)
            let rawType: String? = nil
            let shelterType = ShelterType.matching(from: rawType, name: shelter.name)
            HStack(spacing: 8) {
                // Category Badge
                HStack(spacing: 4) {
                    Image(systemName: shelterType.category == .primary ? "shield.fill" : (shelterType.isVehicleAccessible ? "car.fill" : "building.2.fill"))
                        .font(.system(size: 11, weight: .bold))
                    Text(shelterType.badgeText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundColor(shelterType.category == .primary ? .cyan : (shelterType.isVehicleAccessible ? Color(red: 0.3, green: 0.9, blue: 0.7) : .orange))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    (shelterType.category == .primary ? Color.cyan : (shelterType.isVehicleAccessible ? Color.green : Color.orange)).opacity(0.18)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        (shelterType.category == .primary ? Color.cyan : (shelterType.isVehicleAccessible ? Color.green : Color.orange)).opacity(0.40),
                        lineWidth: 0.8
                    )
                )

                // Night 24/7 Access Badge
                HStack(spacing: 4) {
                    Image(systemName: shelterType.isNightAccessible ? "moon.stars.fill" : "sun.max.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(shelterType.isNightAccessible ? "Цілодобово 24/7" : "Денний доступ")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundColor(shelterType.isNightAccessible ? Color(red: 0.4, green: 0.95, blue: 0.6) : Color.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((shelterType.isNightAccessible ? Color.green : Color.yellow).opacity(0.15))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke((shelterType.isNightAccessible ? Color.green : Color.yellow).opacity(0.35), lineWidth: 0.8)
                )

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            // Route info / error
            if let dist = distanceText, let time = timeText {
                HStack(spacing: 14) {
                    routeStatBadge(icon: "ruler", value: dist, color: .cyan)
                    routeStatBadge(icon: "clock.fill", value: time, color: .green)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
            } else if let error = routeErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
            }

            // Action buttons
            HStack(spacing: 12) {
                if route == nil {
                    Button(action: {
                        #if os(iOS)
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        #endif
                        onRouteRequested()
                    }) {
                        HStack(spacing: 8) {
                            if isCalculatingRoute {
                                ProgressView().tint(.white).scaleEffect(0.85)
                            } else {
                                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            Text(isCalculatingRoute ? "Обчислення..." : "Побудувати маршрут")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.10, green: 0.55, blue: 0.98), Color(red: 0.35, green: 0.25, blue: 0.90)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 5)
                    }
                    .disabled(isCalculatingRoute)
                } else {
                    Button(action: {
                        #if os(iOS)
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        #endif
                        onStartNavigation()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text("Почати навігацію")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.15, green: 0.85, blue: 0.55), Color(red: 0.08, green: 0.65, blue: 0.40)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: Color.green.opacity(0.4), radius: 12, x: 0, y: 5)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 26)
        }
        .background(Color.clear)
    }

    private func routeStatBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(color.opacity(0.16))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
    }
}
