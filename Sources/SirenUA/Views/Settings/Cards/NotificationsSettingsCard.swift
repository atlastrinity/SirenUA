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

    private var soundAlarmsBinding: Binding<Bool> {
        Binding(
            get: { !settings.muteAlarmsSound },
            set: { settings.muteAlarmsSound = !$0 }
        )
    }

    private var soundClearBinding: Binding<Bool> {
        Binding(
            get: { !settings.muteClearSound },
            set: { settings.muteClearSound = !$0 }
        )
    }

    private var soundThreatsBinding: Binding<Bool> {
        Binding(
            get: { !settings.muteThreatsSound },
            set: { settings.muteThreatsSound = !$0 }
        )
    }

    private var soundThreatClearBinding: Binding<Bool> {
        Binding(
            get: { !settings.muteThreatClearSound },
            set: { settings.muteThreatClearSound = !$0 }
        )
    }

    public var body: some View {
        SettingsCard(title: "Сповіщення та Звуки", icon: "bell.fill", iconColor: .siBlue) {
            // Головний вимикач сповіщень
            StyledToggleRow(
                title: "Увімкнути сповіщення",
                subtitle: "Push-повідомлення про тривоги та загрози",
                icon: "bell.fill",
                iconColor: .siBlue,
                isOn: $settings.notificationsEnabled
            )
            .onChange(of: settings.notificationsEnabled) { _, _ in onHaptic(.light) }
            
            StyledDivider()

            // Офіційний блок: Critical Alert + Тривога + Відбій у єдиному скляному контейнері
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ОФІЦІЙНІ СИГНАЛИ ТА CRITICAL ALERT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.siBlue)
                        .tracking(0.5)
                    
                    Text("Критичні сповіщення діють виключно для офіційної тривоги та відбою")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)

                VStack(spacing: 0) {
                    // 1. Критичні сповіщення
                    StyledToggleRow(
                        title: "Критичні сповіщення",
                        subtitle: "Пробивати режим «Не турбувати» для тривоги й відбою",
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .siBlue,
                        isOn: $settings.criticalAlertsEnabled
                    )
                    .disabled(!settings.notificationsEnabled)
                    .opacity(settings.notificationsEnabled ? 1.0 : 0.5)
                    .onChange(of: settings.criticalAlertsEnabled) { _, _ in onHaptic(.light) }

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 8)

                    // 2. Звук офіційної тривоги
                    StyledToggleRow(
                        title: "Звук тривоги",
                        subtitle: "Звуковий сигнал сирени при оголошенні тривоги",
                        icon: "bell.badge.fill",
                        iconColor: .siBlue,
                        isOn: soundAlarmsBinding
                    )
                    .disabled(!settings.notificationsEnabled)
                    .opacity(settings.notificationsEnabled ? 1.0 : 0.5)
                    .onChange(of: settings.muteAlarmsSound) { _, _ in onHaptic(.light) }

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 8)

                    // 3. Звук відбою тривоги
                    StyledToggleRow(
                        title: "Звук відбою тривоги",
                        subtitle: "Звуковий сигнал vidbiy.wav при закінченні офіційної тривоги",
                        icon: "speaker.wave.2.fill",
                        iconColor: .siBlue,
                        isOn: soundClearBinding
                    )
                    .disabled(!settings.notificationsEnabled)
                    .opacity(settings.notificationsEnabled ? 1.0 : 0.5)
                    .onChange(of: settings.muteClearSound) { _, _ in onHaptic(.light) }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.siBlue.opacity(0.25), lineWidth: 1)
                )
            }

            StyledDivider()

            // 4. Звуки ШІ-загроз
            VStack(spacing: 8) {
                StyledToggleRow(
                    title: "Звук ШІ-загроз",
                    subtitle: "Звукові попередження warning.wav про КАБы, ракети та БпЛА",
                    icon: "speaker.wave.1.fill",
                    iconColor: .siBlue,
                    isOn: soundThreatsBinding
                )
                .disabled(!settings.notificationsEnabled)
                .opacity(settings.notificationsEnabled ? 1.0 : 0.5)
                .onChange(of: settings.muteThreatsSound) { _, _ in onHaptic(.light) }

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 4)

                StyledToggleRow(
                    title: "Звук відбою загроз",
                    subtitle: "Звуковий сигнал clearance.wav при скасуванні ШІ-загрози",
                    icon: "speaker.wave.2.bubble.left.fill",
                    iconColor: .siBlue,
                    isOn: soundThreatClearBinding
                )
                .disabled(!settings.notificationsEnabled)
                .opacity(settings.notificationsEnabled ? 1.0 : 0.5)
                .onChange(of: settings.muteThreatClearSound) { _, _ in onHaptic(.light) }
            }

            StyledDivider()

            // 5. Вібрація
            StyledToggleRow(
                title: "Вібрація",
                subtitle: "Вібраційний відгук для всіх типів подій",
                icon: "iphone.radiowaves.left.and.right",
                iconColor: .siBlue,
                isOn: $settings.vibrationEnabled
            )
            .disabled(!settings.notificationsEnabled)
            .opacity(settings.notificationsEnabled ? 1.0 : 0.5)
            .onChange(of: settings.vibrationEnabled) { _, _ in onHaptic(.light) }
        }
    }
}
