import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(
                            colors: [iconColor, iconColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .shadow(color: iconColor.opacity(0.4), radius: 6, x: 0, y: 3)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Separator
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.horizontal, 16)

            // Content
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.16, blue: 0.35).opacity(0.92),
                    Color(red: 0.02, green: 0.08, blue: 0.22).opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.5), Color.blue.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
                .allowsHitTesting(false)
        )
        // Accent left bar
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .fill(iconColor)
                .frame(width: 3)
                .padding(.vertical, 10)
                .allowsHitTesting(false),
            alignment: .leading
        )
    }
}
