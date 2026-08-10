import SwiftUI
import UIKit

struct NotificationsSettingsCard: View {
    @ObservedObject var settings: NotificationSettings
    let onHaptic: (UIImpactFeedbackGenerator.FeedbackStyle) -> Void

    init(
        settings: NotificationSettings,
        onHaptic: @escaping (UIImpactFeedbackGenerator.FeedbackStyle) -> Void
    ) {
        self.settings = settings
        self.onHaptic = onHaptic
    }

    public var body: some View {
        SettingsCard(title: "Сповіщення та Звуки", icon: "bell.fill", iconColor: .siBlue) {
            StyledToggleRow(
                title: "Увімкнути сповіщення",
                subtitle: "Push-повідомлення про тривоги",
                icon: "bell.fill",
                iconColor: .siBlue,
                isOn: $settings.notificationsEnabled
            )
            .onChange(of: settings.notificationsEnabled) { _, _ in onHaptic(.light) }
            
            StyledDivider()
            
            StyledToggleRow(
                title: "Критичні сповіщення",
                subtitle: "Пробивати режим «Не турбувати»",
                icon: "exclamationmark.triangle.fill",
                iconColor: .red,
                isOn: $settings.criticalAlertsEnabled
            )
            .disabled(!settings.notificationsEnabled)
            .opacity(settings.notificationsEnabled ? 1.0 : 0.5)
            .onChange(of: settings.criticalAlertsEnabled) { _, _ in onHaptic(.light) }
            
            StyledDivider()

            StyledToggleRow(
                title: "Без звуку для тривоги",
                subtitle: "Вимкнути звук при офіційній тривозі",
                icon: "bell.slash.fill",
                iconColor: .red,
                isOn: $settings.muteAlarmsSound
            )
            .disabled(!settings.notificationsEnabled)
            .opacity(settings.notificationsEnabled ? 1.0 : 0.5)
            .onChange(of: settings.muteAlarmsSound) { _, _ in onHaptic(.light) }

            StyledDivider()
            
            StyledToggleRow(
                title: "Без звуку для загроз",
                subtitle: "Вимкнути звук для ШІ-попереджень",
                icon: "speaker.slash.circle.fill",
                iconColor: .siOrange,
                isOn: $settings.muteThreatsSound
            )
            .disabled(!settings.notificationsEnabled)
            .opacity(settings.notificationsEnabled ? 1.0 : 0.5)
            .onChange(of: settings.muteThreatsSound) { _, _ in onHaptic(.light) }

            StyledDivider()

            StyledToggleRow(
                title: "Без звуку для відбою",
                subtitle: "Вимкнути звук при відбої тривоги",
                icon: "speaker.slash.fill",
                iconColor: .green,
                isOn: $settings.muteClearSound
            )
            .disabled(!settings.notificationsEnabled)
            .opacity(settings.notificationsEnabled ? 1.0 : 0.5)
            .onChange(of: settings.muteClearSound) { _, _ in onHaptic(.light) }

            StyledDivider()

            StyledToggleRow(
                title: "Вібрація",
                subtitle: "Вібрувати при тривозі, загрозах та відбої",
                icon: "iphone.radiowaves.left.and.right",
                iconColor: .purple,
                isOn: $settings.vibrationEnabled
            )
            .disabled(!settings.notificationsEnabled)
            .opacity(settings.notificationsEnabled ? 1.0 : 0.5)
            .onChange(of: settings.vibrationEnabled) { _, _ in onHaptic(.light) }
        }
    }
}
