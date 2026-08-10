import Foundation
import UserNotifications
import UIKit
import OSLog

private let critLogger = Logger(subsystem: "com.sirenua", category: "CriticalAlert")

/// Legacy stub — all notification logic is now handled by NotificationManager.
/// Sound, vibration, and interruption level decisions are made purely client-side
/// via NotificationSettings (6 toggles).
/// This class is retained only for backward compatibility; it does nothing.
final class CriticalAlertManager: NSObject {
    static let shared = CriticalAlertManager()

    override private init() {
        super.init()
        critLogger.info("CriticalAlertManager is deprecated — all logic is in NotificationManager")
    }

    func sendCriticalAlert(region: String, isActive: Bool) {
        // No-op: handled by NotificationManager.sendAlertNotification / sendClearNotification
        critLogger.debug("sendCriticalAlert called (no-op) for \(region), isActive=\(isActive)")
    }

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        critLogger.info("Cleared all pending and delivered notifications")
    }
}
