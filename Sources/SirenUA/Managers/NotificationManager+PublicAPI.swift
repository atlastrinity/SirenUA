import Foundation
import UserNotifications
import AudioToolbox
import UIKit

// MARK: - Public API & Sound Configuration

extension NotificationManager {

    // MARK: - Public Triggers

    func sendAlertNotification(for regionName: String) {
        let fullTitle = "🚨 Повітряна тривога — \(regionName)"
        let body = "Повітряна тривога в: \(regionName). Прямуйте в укриття!"
        let config = soundConfig(for: .alarm)

        enqueue(title: fullTitle, body: body, soundName: config.soundName, regionName: regionName,
                interruptionLevel: config.level, relevanceScore: 1.0)

        triggerHaptic(.warning, pulses: 4)
    }

    func sendThreatNotification(for regionName: String, title: String, body: String,
                                confidence: Int = 75, isCritical: Bool = false) {
        let config = soundConfig(for: .threat, isCritical: isCritical, confidence: confidence)

        var fullTitle = title
        if !title.contains(regionName) {
            fullTitle = "\(title) — \(regionName)"
        }

        enqueue(title: fullTitle, body: body, soundName: config.soundName, regionName: regionName,
                interruptionLevel: config.level, relevanceScore: config.relevance)

        triggerHaptic(confidence >= 85 ? .error : .warning, pulses: 3)
    }

    func sendClearNotification(for regionName: String) {
        let title = "🟢 Відбій тривоги — \(regionName)"
        let body  = "Відбій повітряної тривоги в: \(regionName)."
        let config = soundConfig(for: .clear)

        enqueue(title: title, body: body, soundName: config.soundName, regionName: regionName,
                interruptionLevel: config.level, relevanceScore: 0.3)

        triggerHaptic(.success, pulses: 2)
    }

    // MARK: - Sound Configuration Helper

    /// Єдина точка визначення звуку та interruption level для типу події.
    /// Консолідує перевірку тоглів, маппінг на звуковий файл та рівень переривання.
    func soundConfig(
        for eventType: EventType,
        isCritical: Bool = false,
        confidence: Int = 75
    ) -> (soundName: String, level: UNNotificationInterruptionLevel, relevance: Double) {
        let settings = NotificationSettings.shared

        // 1. Перевірка тогла мʼюту для відповідного типу події
        let shouldPlay: Bool
        switch eventType {
        case .alarm:  shouldPlay = settings.shouldPlayAlarmSound
        case .threat: shouldPlay = settings.shouldPlayThreatSound
        case .clear:  shouldPlay = settings.shouldPlayClearSound
        }

        // 2. Звуковий файл — завжди з EventType.soundFile (єдине джерело правди)
        let soundName = shouldPlay ? eventType.soundFile : ""

        // 3. Interruption level
        let bypassDND = settings.isCriticalAlertsEnabled
        let level: UNNotificationInterruptionLevel
        let relevance: Double

        switch eventType {
        case .alarm:
            level = bypassDND ? .timeSensitive : .active
            relevance = 1.0
        case .clear:
            level = bypassDND ? .timeSensitive : .active
            relevance = 0.3
        case .threat:
            if isCritical || confidence >= 85 {
                level = .timeSensitive
                relevance = 0.8
            } else if confidence >= 60 {
                level = .timeSensitive
                relevance = 0.6
            } else {
                level = .active
                relevance = 0.4
            }
        }

        return (soundName, level, relevance)
    }

    // MARK: - Haptic Feedback

    func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType, pulses: Int = 3) {
        guard NotificationSettings.shared.shouldVibrate else { return }
        DispatchQueue.main.async {
            #if os(iOS)
            for i in 0..<pulses {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.35) {
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                    let generator = UINotificationFeedbackGenerator()
                    generator.prepare()
                    generator.notificationOccurred(type)
                }
            }
            #endif
        }
    }
}
