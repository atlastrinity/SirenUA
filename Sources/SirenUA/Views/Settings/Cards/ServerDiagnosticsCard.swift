import SwiftUI

struct ServerDiagnosticsCard: View {
    let ukraineAlarmStatus: SettingsView.ServerStatus
    let ubillingStatus: SettingsView.ServerStatus
    let alertsInUaStatus: SettingsView.ServerStatus
    let threatsServerStatus: SettingsView.ServerStatus
    let geminiServerStatus: SettingsView.ServerStatus
    let onRefresh: () -> Void

    var body: some View {
        SettingsCard(title: "Діагностика з'єднання та API", icon: "network", iconColor: .purple) {
            ServerStatusRow(
                name: "1. UkraineAlarm API v3 (Tier 1)",
                url: "api.ukrainealarm.com",
                status: ukraineAlarmStatus
            )

            StyledDivider()

            ServerStatusRow(
                name: "2. UBilling Дзеркало (Tier 2)",
                url: "ubilling.net.ua",
                status: ubillingStatus
            )

            StyledDivider()

            ServerStatusRow(
                name: "3. Alerts.in.ua API (Tier 3)",
                url: "api.alerts.in.ua",
                status: alertsInUaStatus
            )

            StyledDivider()

            ServerStatusRow(
                name: "Сервер загроз (SirenUA Backend)",
                url: NetworkManager.serverURL.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: ""),
                status: threatsServerStatus
            )

            StyledDivider()

            ServerStatusRow(
                name: "Аналізатор ШІ (Gemini 2.5)",
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

