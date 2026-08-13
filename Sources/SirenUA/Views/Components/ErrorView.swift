import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Notification Extension
extension Notification.Name {
    static let refreshAlerts = Notification.Name("refreshAlerts")
}

// MARK: - ErrorView (Sleek Floating Offline Status Pill)
struct ErrorView: View {
    let message: String
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            // Animated status dot
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(pulse ? 0.35 : 0.1))
                    .frame(width: 16, height: 16)
                    .scaleEffect(pulse ? 1.3 : 0.85)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .fill(Color.orange)
                    .frame(width: 7, height: 7)
            }

            Image(systemName: "wifi.slash")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.orange)

            Text(message)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .background(Color(red: 0.1, green: 0.08, blue: 0.05).opacity(0.85))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
        .onAppear { pulse = true }
    }
}
