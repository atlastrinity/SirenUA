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

            // Перевірка дозволу на відтворення звуку через централізовану політику (NotificationSoundPolicy)
            let shared = UserDefaults(suiteName: NotificationSettings.suiteName)
            let allowSoundPlayback = NotificationSoundPolicy.shouldAllowPlayback(
                for: eventType,
                regionName: regionName,
                shouldPlaySoundByUser: shouldPlaySound,
                sharedDefaults: shared,
                now: now
            )

            if allowSoundPlayback && notification.request.content.sound != nil {
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
