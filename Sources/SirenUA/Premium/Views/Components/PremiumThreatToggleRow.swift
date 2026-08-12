import SwiftUI

/// Рядок перемикача налаштувань загроз з інтегрованим блокуванням для не-преміум користувачів
struct PremiumThreatToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @Binding var isOn: Bool
    let isPremium: Bool
    let onLockedTap: () -> Void

    init(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color = .siBlue,
        isOn: Binding<Bool>,
        isPremium: Bool,
        onLockedTap: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self._isOn = isOn
        self.isPremium = isPremium
        self.onLockedTap = onLockedTap
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isPremium ? iconColor : .gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isPremium ? .white : .white.opacity(0.6))

                    if !isPremium {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8, weight: .bold))
                            Text("PREMIUM")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.siGold)
                        .clipShape(Capsule())
                    }
                }

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
            }

            Spacer()

            if isPremium {
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.siBlue)
            } else {
                Button(action: {
                    onLockedTap()
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.siGold)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isPremium {
                onLockedTap()
            }
        }
    }
}
