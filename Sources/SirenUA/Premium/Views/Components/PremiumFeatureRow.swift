import SwiftUI

/// Рядок опису можливості Premium (для карток налаштувань та переліку фіч)
struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        color: Color = .siGold
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
    }

    init(feature: PremiumFeature) {
        self.icon = feature.iconName
        self.title = feature.title
        self.subtitle = feature.subtitle
        self.color = feature.accentColor
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()
        }
    }
}
