import Foundation
import UserNotifications
import UIKit
import OSLog

private let critLogger = Logger(subsystem: "com.sirenua", category: "CriticalAlert")

final class CriticalAlertManager: NSObject {
    static let shared = CriticalAlertManager()

    override private init() {
        super.init()
        setupNotification()
    }

    private func setupNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .criticalAlert]) { granted, error in
            if let error = error {
                critLogger.error("Error requesting notification authorization: \(error.localizedDescription)")
            }
            if granted {
                critLogger.info("Notification authorization granted")
            }
        }
        
        // Removed `center.delegate = self` to prevent overwriting NotificationManager's delegate registration.
        // If critical alerts need handling in foreground, they can be processed through NotificationManager.
    }

    func sendCriticalAlert(region: String, isActive: Bool) {
        let center = UNUserNotificationCenter.current()

        if isActive {
            let muteAlarms = UserDefaults.standard.bool(forKey: "muteAlarmsSound")

            // Send critical alert
            let content = UNMutableNotificationContent()
            content.title = "AIR RAID ALERT"
            content.body = "⚠️ AIR RAID ALERT IN \(region.uppercased()) ⚠️"
            content.sound = muteAlarms ? nil : .defaultCritical
            content.categoryIdentifier = "AIR_RAID_ALERT"
            content.interruptionLevel = .critical
            content.userInfo = ["region": region]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

            center.add(request) { error in
                if let error = error {
                    critLogger.error("Error sending critical alert: \(error.localizedDescription)")
                } else {
                    critLogger.info("Critical alert sent for \(region)")
                }
            }

            triggerVibration(.warning)
        } else {
            let muteClear = UserDefaults.standard.bool(forKey: "muteClearSound")

            // Send end alert with vidbiy.wav
            let content = UNMutableNotificationContent()
            content.title = "ALERT ENDED"
            content.body = "Air raid alert has ended in \(region.uppercased())"
            content.sound = muteClear ? nil : UNNotificationSound(named: UNNotificationSoundName("vidbiy.wav"))
            content.categoryIdentifier = "ALERT_ENDED"

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

            center.add(request) { error in
                if let error = error {
                    critLogger.error("Error sending alert end notification: \(error.localizedDescription)")
                } else {
                    critLogger.info("Alert ended notification sent for \(region)")
                }
            }

            triggerVibration(.success)
        }
    }

    private func triggerVibration(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let vibrationOn = UserDefaults.standard.object(forKey: "vibrationEnabled") as? Bool ?? true
        guard vibrationOn else { return }
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(type)
        }
    }

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        critLogger.info("Cleared all pending and delivered notifications")
    }
}
