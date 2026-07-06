import SwiftUI
import UIKit

// MARK: - Notification Extension
extension Notification.Name {
    static let refreshAlerts = Notification.Name("refreshAlerts")
}

// MARK: - ErrorView
@available(iOS 16.0, *)
struct ErrorView: View {
    let message: String
    @State private var isRetrying = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 16) {
            // Animated warning icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(pulse ? 0.08 : 0.04))
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulse ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .red.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 5) {
                Text("Помилка з'єднання")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Text(message)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            Button(action: retry) {
                HStack(spacing: 6) {
                    if isRetrying {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .bold))
                    }
                    Text(isRetrying ? "Оновлення..." : "Спробувати знову")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    LinearGradient(
                        colors: [Color.red.opacity(0.7), Color.red.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color.red.opacity(0.25), radius: 6, x: 0, y: 3)
            }
            .disabled(isRetrying)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 22)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.red.opacity(0.15), radius: 12, x: 0, y: 5)
        .onAppear { pulse = true }
    }

    private func retry() {
        isRetrying = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        NotificationCenter.default.post(name: .refreshAlerts, object: nil)
        // Reset button after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            isRetrying = false
        }
    }
}
