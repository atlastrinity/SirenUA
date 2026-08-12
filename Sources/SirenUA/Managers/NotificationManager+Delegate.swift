import Foundation
import UserNotifications
import UIKit
import OSLog

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                completionHandler([.banner, .sound, .badge, .list])
                return
            }

            guard NotificationSettings.shared.notificationsEnabled else {
                completionHandler([])
                return
            }

            let userInfo = notification.request.content.userInfo
            var regionName: String? = userInfo["region"] as? String ?? userInfo["regionName"] as? String
            if regionName == nil, let aps = userInfo["aps"] as? [String: Any],
               let custom = aps["custom_data"] as? [String: Any] {
                regionName = custom["region"] as? String
            }
            if let region = regionName, !NotificationSettings.shared.isTracked(region) {
                completionHandler([])
                return
            }

            // Resolve event type using canonical EventType enum (same logic as NSE)
            let eventType = EventType.resolve(from: userInfo, title: notification.request.content.title)

            let shouldPlaySound: Bool
            switch eventType {
            case .threat:      shouldPlaySound = NotificationSettings.shared.shouldPlayThreatSound
            case .clear:       shouldPlaySound = NotificationSettings.shared.shouldPlayClearSound
            case .alarm:       shouldPlaySound = NotificationSettings.shared.shouldPlayAlarmSound
            case .threatClear: shouldPlaySound = NotificationSettings.shared.shouldPlayThreatClearSound
            }

            let now = Date()
            // Haptic feedback (only works in foreground)
            if NotificationSettings.shared.shouldVibrate {
                let hapticType: UINotificationFeedbackGenerator.FeedbackType
                let pulses: Int
                switch eventType {
                case .alarm:               hapticType = .error;   pulses = 4
                case .clear, .threatClear: hapticType = .success; pulses = 2
                case .threat:              hapticType = .warning; pulses = 3
                }
                self.triggerHaptic(hapticType, pulses: pulses)
            }

            // Дедуплікація, пріоритетизація та перевірка завершення фрази (3.5с), гармонізовано з NSE
            let minVoiceDuration: TimeInterval = 3.5
            let shared = UserDefaults(suiteName: NotificationSettings.suiteName)
            let lastSoundType = shared?.string(forKey: "lastSoundEventType") ?? ""
            let lastSoundRegion = shared?.string(forKey: "lastSoundRegion") ?? ""
            let lastSoundTime = shared?.double(forKey: "lastSoundTimestamp") ?? 0.0
            let timeSinceLastSound = now.timeIntervalSince1970 - lastSoundTime

            var allowSoundPlayback = shouldPlaySound

            if shouldPlaySound && timeSinceLastSound < Self.soundThrottle {
                let currentRegion = regionName ?? ""
                let isSameRegion = (!currentRegion.isEmpty && currentRegion == lastSoundRegion)

                if timeSinceLastSound < minVoiceDuration {
                    // Мінімальне вікно 3.5с: якщо попередня фраза ще озвучується, не обриваємо її на півслові!
                    allowSoundPlayback = false
                    notifLogger.info("Foreground: Suppressing sound (previous voice line still playing: \(timeSinceLastSound)s < 3.5s)")
                } else if (eventType == .clear || eventType == .threatClear) && isSameRegion {
                    // ВІДБІЙ ДЛЯ ТІЄЇ Ж ОБЛАСТІ -> ПЕРЕБИВАЄ СИРЕНУ/ЗАГРОЗУ ЦІЄЇ ОБЛАСТІ ПІСЛЯ ЗАВЕРШЕННЯ ФРАЗИ!
                    allowSoundPlayback = true
                    notifLogger.info("Foreground: Clearance for SAME region (\(currentRegion)) -> Overriding sound for \(eventType.rawValue)")
                } else if eventType.rawValue == lastSoundType {
                    allowSoundPlayback = false
                    notifLogger.info("Foreground: Suppressing duplicate \(eventType.rawValue) sound for another region (\(currentRegion))")
                } else if lastSoundType == "alarm" && (eventType == .threat || eventType == .clear || eventType == .threatClear) {
                    allowSoundPlayback = false
                    notifLogger.info("Foreground: Suppressing \(eventType.rawValue) sound for \(currentRegion) while alarm is active for \(lastSoundRegion)")
                } else if lastSoundType == "threat" && (eventType == .clear || eventType == .threatClear) && timeSinceLastSound < 5.0 {
                    allowSoundPlayback = false
                    notifLogger.info("Foreground: Suppressing clear sound for \(currentRegion) while threat is active")
                }
            }

            if allowSoundPlayback && notification.request.content.sound != nil {
                shared?.set(eventType.rawValue, forKey: "lastSoundEventType")
                shared?.set(regionName ?? "", forKey: "lastSoundRegion")
                shared?.set(now.timeIntervalSince1970, forKey: "lastSoundTimestamp")
                self.lastPlayedTime = now
                completionHandler([.banner, .sound, .badge, .list])
            } else {
                completionHandler([.banner, .badge, .list])
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        var regionName: String? = nil
        if let reg = userInfo["region"] as? String {
            regionName = reg
        } else if let reg = userInfo["regionName"] as? String {
            regionName = reg
        } else if let reg = userInfo["aps"] as? [String: Any],
                  let custom = reg["custom_data"] as? [String: Any],
                  let region = custom["region"] as? String {
            regionName = region
        }

        DispatchQueue.main.async {
            // Instantly notify AlertViewModelV3 to fetch authoritative state and clear any finished alerts
            NotificationCenter.default.post(
                name: NSNotification.Name("ThreatDataUpdated"),
                object: nil,
                userInfo: userInfo
            )

            if let regionName = regionName, !regionName.isEmpty {
                NotificationManager.shared.pendingTappedRegion = regionName
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenRegionDetail"),
                    object: nil,
                    userInfo: ["regionName": regionName]
                )
            }
        }
        completionHandler()
    }
}
