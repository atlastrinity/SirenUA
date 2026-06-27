import Foundation
import UserNotifications

@available(iOS 17.0, *)
class CriticalAlertManager: NSObject {
    static let shared = CriticalAlertManager()

    override init() {
        super.init()
        setupNotification()
    }

    private func setupNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .criticalAlert]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error)")
            }
            if granted {
                print("Notification authorization granted")
            }
        }

        center.delegate = self
    }

    func sendCriticalAlert(region: String, isActive: Bool) {
        let center = UNUserNotificationCenter.current()

        if isActive {
            // Send critical alert
            let content = UNMutableNotificationContent()
            content.title = "AIR RAID ALERT"
            content.body = "⚠️ AIR RAID ALERT IN \(region.uppercased()) ⚠️"
            content.sound = .defaultCritical
            content.categoryIdentifier = "AIR_RAID_ALERT"
            content.interruptionLevel = .critical
            content.userInfo = ["region": region]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

            center.add(request) { error in
                if let error = error {
                    print("Error sending critical alert: \(error)")
                } else {
                    print("Critical alert sent for \(region)")
                }
            }
        } else {
            // Send end alert
            let content = UNMutableNotificationContent()
            content.title = "ALERT ENDED"
            content.body = "Air raid alert has ended in \(region.uppercased())"
            content.sound = .default
            content.categoryIdentifier = "ALERT_ENDED"

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

            center.add(request) { error in
                if let error = error {
                    print("Error sending alert end notification: \(error)")
                } else {
                    print("Alert ended notification sent for \(region)")
                }
            }
        }
    }

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

@available(iOS 17.0, *)
extension CriticalAlertManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let region = userInfo["region"] as? String {
            print("User tapped alert for: \(region)")
        }
        completionHandler()
    }
}
