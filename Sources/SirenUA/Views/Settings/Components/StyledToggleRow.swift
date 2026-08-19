import SwiftUI

// MARK: - StyledToggleRow
struct StyledToggleRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = .white
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(isOn ? iconColor : .white.opacity(0.35))
                        .frame(width: 18)
                        .animation(.easeInOut(duration: 0.2), value: isOn)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
            }
        }
        .tint(iconColor)
        .onChange(of: isOn) { oldValue, newValue in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - StyledDivider
struct StyledDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.vertical, 2)
    }
}

// MARK: - ToggleRow (Legacy — kept for compatibility)
struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .onChange(of: isOn) { oldValue, newValue in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - ServerStatusRow
struct ServerStatusRow: View {
    let name: String
    let url: String
    let status: SettingsView.ServerStatus

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(url)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            statusBadge
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .checking:
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .scaleEffect(pulse ? 1.3 : 0.7)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                Text("Перевірка...")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05))
            .clipShape(Capsule())

        case .online(let label):
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(red: 0.18, green: 0.80, blue: 0.55))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color(red: 0.18, green: 0.80, blue: 0.55).opacity(0.7), radius: 3)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.18, green: 0.80, blue: 0.55))
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color(red: 0.18, green: 0.80, blue: 0.55).opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(red: 0.18, green: 0.80, blue: 0.55).opacity(0.25), lineWidth: 1))

        case .offline(let error):
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)
                    .shadow(color: Color.red.opacity(0.6), radius: 4)
                Text(error.count > 25 ? String(error.prefix(22)) + "..." : error)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.red.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.red.opacity(0.25), lineWidth: 1))
        }
    }
}
