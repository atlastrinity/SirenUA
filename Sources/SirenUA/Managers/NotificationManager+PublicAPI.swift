import Foundation
import UserNotifications
import UIKit

// MARK: - Public API & Sound Configuration

extension NotificationManager {

    // MARK: - Public Triggers

    func sendAlertNotification(for regionName: String) {
        let fullTitle = "🚨 Повітряна тривога — \(regionName)"
        let body = "Повітряна тривога в: \(regionName). Прямуйте в укриття!"
        let config = soundConfig(for: .alarm)

        enqueue(title: fullTitle, body: body, soundName: config.soundName, regionName: regionName,
                eventType: .alarm,
                interruptionLevel: config.level, relevanceScore: 1.0)
    }

    func sendThreatNotification(for regionName: String, title: String, body: String,
                                confidence: Int = 75) {
        let isPremium = NotificationSettings.shared.isPremium || (UserDefaults(suiteName: NotificationSettings.suiteName)?.bool(forKey: "premiumEnabled") ?? false)
        guard isPremium else { return }

        let config = soundConfig(for: .threat, confidence: confidence)

        var fullTitle = title
        if !title.contains(regionName) {
            fullTitle = "\(title) — \(regionName)"
        }

        enqueue(title: fullTitle, body: body, soundName: config.soundName, regionName: regionName,
                eventType: .threat,
                interruptionLevel: config.level, relevanceScore: config.relevance)
    }

    func sendClearNotification(for regionName: String) {
        let title = "🟢 Відбій тривоги — \(regionName)"
        let body  = "Відбій повітряної тривоги в: \(regionName)."
        let config = soundConfig(for: .clear)

        enqueue(title: title, body: body, soundName: config.soundName, regionName: regionName,
                eventType: .clear,
                interruptionLevel: config.level, relevanceScore: 0.5)
    }

    func sendThreatClearNotification(for regionName: String) {
        let isPremium = NotificationSettings.shared.isPremium || (UserDefaults(suiteName: NotificationSettings.suiteName)?.bool(forKey: "premiumEnabled") ?? false)
        guard isPremium else { return }

        let title = "🟢 Відбій загрози — \(regionName)"
        let body  = "Загрозу нейтралізовано в: \(regionName)."
        let config = soundConfig(for: .threatClear)

        enqueue(title: title, body: body, soundName: config.soundName, regionName: regionName,
                eventType: .threatClear,
                interruptionLevel: config.level, relevanceScore: 0.3)
    }

    // MARK: - Sound Configuration Helper

    /// Єдина точка визначення звуку та interruption level для типу події.
    /// Консолідує перевірку тоглів, маппінг на звуковий файл та рівень переривання.
    func soundConfig(
        for eventType: EventType,
        confidence: Int = 75
    ) -> (soundName: String, level: UNNotificationInterruptionLevel, relevance: Double) {
        let settings = NotificationSettings.shared

        // 1. Перевірка тогла мʼюту для відповідного типу події
        let shouldPlay: Bool
        switch eventType {
        case .alarm:       shouldPlay = settings.shouldPlayAlarmSound
        case .threat:      shouldPlay = settings.shouldPlayThreatSound
        case .clear:       shouldPlay = settings.shouldPlayClearSound
        case .threatClear: shouldPlay = settings.shouldPlayThreatClearSound
        }

        // 2. Звуковий файл — завжди з EventType.soundFile (єдине джерело правди)
        let soundName = shouldPlay ? eventType.soundFile : ""

        // 3. Interruption level (Critical Alerts діють виключно для .alarm та .clear)
        let bypassDND = settings.isCriticalAlertsEnabled
        let level: UNNotificationInterruptionLevel
        let relevance: Double

        switch eventType {
        case .alarm:
            level = bypassDND ? .timeSensitive : .active
            relevance = 1.0
        case .clear:
            level = bypassDND ? .timeSensitive : .active
            relevance = 0.5
        case .threat:
            // ШІ-загрози мають timeSensitive для уваги, але НІКОЛИ не є critical
            level = .timeSensitive
            relevance = (confidence >= 85) ? 0.8 : (confidence >= 60 ? 0.6 : 0.4)
        case .threatClear:
            level = .active
            relevance = 0.3
        }

        return (soundName, level, relevance)
    }

    // MARK: - Haptic Feedback

    /// Генерує тактильний зворотний зв'язок (Taptic Engine) з заданою кількістю пульсів.
    ///
    /// Використовує єдиний `UINotificationFeedbackGenerator` з попереднім `prepare()`
    /// для надійної роботи Taptic Engine. Без AudioServicesPlaySystemSound, щоб
    /// уникнути конфлікту між двома вібро-механізмами.
    func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType, pulses: Int = 3) {
        guard NotificationSettings.shared.shouldVibrate else { return }
        #if os(iOS)
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            // Перший пульс після невеликої затримки, щоб Taptic Engine встиг «розігрітися»
            for i in 0..<pulses {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 + Double(i) * 0.35) {
                    generator.notificationOccurred(type)
                }
            }
        }
        #endif
    }
}
