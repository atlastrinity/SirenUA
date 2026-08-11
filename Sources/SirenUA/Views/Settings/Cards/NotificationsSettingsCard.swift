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

            // Офіційній блок: Тривога та Відбій у витонченій напіврамці
            VStack(spacing: 0) {
                StyledToggleRow(
                    title: "Без звуку для тривоги",
                    subtitle: "Вимкнути звук сирени при офіційній тривозі",
                    icon: "bell.slash.fill",
                    iconColor: .red,
                    isOn: $settings.muteAlarmsSound
                )
                .disabled(!settings.notificationsEnabled)
                .opacity(settings.notificationsEnabled ? 1.0 : 0.5)
                .onChange(of: settings.muteAlarmsSound) { _, _ in onHaptic(.light) }

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 8)

                StyledToggleRow(
                    title: "Без звуку для відбою",
                    subtitle: "Вимкнути звук при завершенні небезпеки",
                    icon: "speaker.slash.fill",
                    iconColor: .green,
                    isOn: $settings.muteClearSound
                )
                .disabled(!settings.notificationsEnabled)
                .opacity(settings.notificationsEnabled ? 1.0 : 0.5)
                .onChange(of: settings.muteClearSound) { _, _ in onHaptic(.light) }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            StyledDivider()

            StyledToggleRow(
                title: "Без звуку для загроз",
                subtitle: "Вимкнути звук ШІ-попереджень про КАБи та дрони",
                icon: "speaker.slash.circle.fill",
                iconColor: .siOrange,
                isOn: $settings.muteThreatsSound
            )
            .disabled(!settings.notificationsEnabled)
            .opacity(settings.notificationsEnabled ? 1.0 : 0.5)
            .onChange(of: settings.muteThreatsSound) { _, _ in onHaptic(.light) }

            StyledDivider()

            StyledToggleRow(
                title: "Вібрація",
                subtitle: "Вібрувати при тривогах, загрозах та відбої",
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
