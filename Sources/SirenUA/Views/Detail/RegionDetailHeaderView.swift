import SwiftUI

struct RegionDetailHeaderView: View {
    let regionName: String
    let statusTitle: String
    let themeColor: Color
    let isActive: Bool
    let isThreatActive: Bool
    let lastChanged: String?
    let threatTime: String?

    @State private var isPulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header status card
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.15))
                        .frame(width: 46, height: 46)
                        .scaleEffect(isPulsing && (isActive || isThreatActive) ? 1.15 : 1.0)
                        .opacity(isPulsing && (isActive || isThreatActive) ? 0.6 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
                    Image(systemName: isActive ? "exclamationmark.triangle.fill" : (isThreatActive ? "bell.badge.fill" : "checkmark.circle.fill"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(themeColor)
                }
                .shadow(color: themeColor.opacity(0.4), radius: 8)
                .onAppear { isPulsing = true }

                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColor)

                    if let time = threatTime {
                        Text("Виявлено: \(time)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.45))
                    } else if let changed = lastChanged {
                        Text(changed)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .background(themeColor.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [themeColor.opacity(0.4), themeColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: themeColor.opacity(0.15), radius: 12)

            // Region name card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(themeColor)
                        .font(.system(size: 14))
                    Text("Область")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(regionName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(radius: 15)
        }
    }
}
