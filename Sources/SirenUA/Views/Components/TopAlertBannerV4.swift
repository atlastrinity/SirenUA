import SwiftUI

struct TopAlertBannerV4: View {
    let statusColor: Color
    let statusText: String
    let activeCount: Int
    let isLoading: Bool

    // Computed icon based on semantic state, not color comparison
    private var statusIcon: String {
        if activeCount > 0 {
            return statusText == "ТРИВОГА" ? "bell.badge.fill" : "exclamationmark.triangle.fill"
        }
        return "checkmark.shield.fill"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.system(size: 20, weight: .bold))
                .symbolEffect(.bounce, options: .repeating, value: activeCount)
                .shadow(color: statusColor.opacity(0.5), radius: 6)

            VStack(spacing: 2) {
                Text(statusText)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(statusColor.opacity(0.9))
                    .tracking(1.5)
                Text(isLoading ? "ОНОВЛЕННЯ..." : "\(activeCount) АКТИВНИХ")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundColor(statusColor)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.75))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [statusColor.opacity(0.9), statusColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: statusColor.opacity(0.4), radius: 15, x: 0, y: 5)
    }
}
