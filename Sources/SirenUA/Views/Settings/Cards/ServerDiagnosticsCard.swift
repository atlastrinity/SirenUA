import SwiftUI

struct ServerDiagnosticsCard: View {
    let alertsServerStatus: SettingsView.ServerStatus
    let threatsServerStatus: SettingsView.ServerStatus
    let geminiServerStatus: SettingsView.ServerStatus
    let onRefresh: () -> Void

    var body: some View {
        SettingsCard(title: "Діагностика з'єднання", icon: "network", iconColor: .purple) {
            ServerStatusRow(
                name: "Основний сервер тривог",
                url: "ubilling.net.ua",
                status: alertsServerStatus
            )

            StyledDivider()

            ServerStatusRow(
                name: "Сервер загроз (Premium)",
                url: "sirenua-threatserver.onrender.com",
                status: threatsServerStatus
            )

            StyledDivider()

            ServerStatusRow(
                name: "Аналізатор ШІ (Gemini)",
                url: "gemini-2.5-flash",
                status: geminiServerStatus
            )

            HStack {
                Spacer()
                Button(action: onRefresh) {
                    Label("Оновити статус", systemImage: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ChartColorTheme.accent)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(ChartColorTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }
}
