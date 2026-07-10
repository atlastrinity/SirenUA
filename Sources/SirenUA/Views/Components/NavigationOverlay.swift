import SwiftUI
import MapKit

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
