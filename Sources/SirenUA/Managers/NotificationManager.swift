import Foundation
import UserNotifications
import UIKit
import OSLog

let notifLogger = Logger(subsystem: "com.sirenua", category: "Notifications")

// MARK: - PendingNotification

struct PendingNotification {
    let title: String
    let body: String
    let soundName: String
    let interruptionLevel: UNNotificationInterruptionLevel
    let relevanceScore: Double
    let regionName: String
    let eventType: EventType
}

// MARK: - NotificationManager

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = NotificationManager()

    /// Track the region name when user taps a push notification
    var pendingTappedRegion: String? = nil

    /// Serial queue for notification delivery to prevent overlap
    private var notificationQueue: [PendingNotification] = []
    private var isProcessingQueue = false

    /// Sound throttle: prevent notification sounds from overlapping.
    /// Unified 15s throttle — aligned with NSE to avoid sound conflicts.
    var lastPlayedTime: Date?
    static let soundThrottle: TimeInterval = 15.0

    /// Registry of recently delivered/enqueued notifications to prevent local/remote duplicates (15s window)
    private var recentlyNotifiedEvents: [String: Date] = [:]
    static let duplicateThrottleWindow: TimeInterval = 15.0

    /// Task for managing topic synchronization
    var syncTask: Task<Void, Never>? = nil

    // MARK: - Init

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Authorization

    func requestAuthorization() {
        guard NotificationSettings.shared.isNotificationsEnabled else { return }
        
        // Request WITH criticalAlert — succeeds only if the entitlement is provisioned by Apple.
        // NSE handles the actual critical vs timeSensitive decision per-notification.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .criticalAlert]) { granted, error in
            if let error {
                notifLogger.warning("Critical alert request failed (expected without entitlement): \(error.localizedDescription)")
                // Re-request without criticalAlert
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, err in
                    if let err {
                        notifLogger.error("Fallback permission request error: \(err.localizedDescription)")
                    } else {
                        notifLogger.info("Notification permission (standard): \(granted ? "granted" : "denied")")
                        if granted {
                            DispatchQueue.main.async {
                                UIApplication.shared.registerForRemoteNotifications()
                            }
                        }
                    }
                }
            } else {
                notifLogger.info("Notification permission: \(granted ? "granted" : "denied")")
                if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
            
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                notifLogger.info("Critical alerts: \(settings.criticalAlertSetting == .enabled ? "ENABLED" : "NOT AVAILABLE")")
                notifLogger.info("Time sensitive: \(settings.timeSensitiveSetting == .enabled ? "ENABLED" : "NOT AVAILABLE")")
            }
        }
    }

    // MARK: - Deduplication Registry

    func recordRecentNotification(regionName: String, eventType: String, date: Date = Date()) {
        let key = "\(regionName)_\(eventType)"
        recentlyNotifiedEvents[key] = date
    }

    func wasRecentlyNotified(regionName: String, eventType: String, now: Date = Date()) -> Bool {
        let key = "\(regionName)_\(eventType)"
        if let last = recentlyNotifiedEvents[key], now.timeIntervalSince(last) < Self.duplicateThrottleWindow {
            return true
        }
        return false
    }

    // MARK: - Queue Management

    func enqueue(title: String, body: String, soundName: String, regionName: String,
                 eventType: EventType,
                 interruptionLevel: UNNotificationInterruptionLevel = .active,
                 relevanceScore: Double = 0.5) {
        guard NotificationSettings.shared.isNotificationsEnabled else { return }
        guard NotificationSettings.shared.isTracked(regionName) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let now = Date()

            // Check if this region & event was already notified within the throttle window (e.g. from remote FCM push)
            if self.wasRecentlyNotified(regionName: regionName, eventType: eventType.rawValue, now: now) {
                notifLogger.debug("Local notification for \(regionName) (\(eventType.rawValue)) suppressed — duplicate within \(Self.duplicateThrottleWindow)s")
                return
            }
            self.recordRecentNotification(regionName: regionName, eventType: eventType.rawValue, date: now)

            let playSoundForThis: Bool
            if soundName.isEmpty {
                playSoundForThis = false
            } else if let last = self.lastPlayedTime, now.timeIntervalSince(last) < Self.soundThrottle {
                playSoundForThis = false
                notifLogger.debug("Notification sound for \(regionName) throttled (within \(Self.soundThrottle)s)")
            } else {
                playSoundForThis = true
                self.lastPlayedTime = now
            }

            // Sound plays ONLY through UNNotificationSound (set in processQueue).
            // No AVAudioPlayer — avoids double-playback with NSE push sound.

            self.notificationQueue.append(PendingNotification(
                title: title,
                body: body,
                soundName: playSoundForThis ? soundName : "",
                interruptionLevel: interruptionLevel,
                relevanceScore: relevanceScore,
                regionName: regionName,
                eventType: eventType
            ))
            self.processQueue()
        }
    }

    private func processQueue() {
        guard !isProcessingQueue, !notificationQueue.isEmpty else { return }
        isProcessingQueue = true
        let item = notificationQueue.removeFirst()

        let content       = UNMutableNotificationContent()
        content.title     = item.title
        content.body      = item.body
        content.userInfo  = [
            "region": item.regionName,
            "event_type": item.eventType.rawValue
        ]

        // Interruption level for lock screen / Focus delivery
        content.interruptionLevel = item.interruptionLevel
        content.relevanceScore = item.relevanceScore
        
        // Sound: for local (foreground) notifications, use named sound file.
        // Remote push sound is handled by NotificationServiceExtension (NSE).
        if !item.soundName.isEmpty {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(item.soundName))
        } else {
            content.sound = nil
        }

        // Canonical deterministic identifier per region & channel to update banners seamlessly
        let identifier: String
        switch item.eventType {
        case .alarm, .clear:
            identifier = "sirenua_alarm_\(item.regionName)"
        case .threat, .threatClear:
            identifier = "sirenua_threat_\(item.regionName)"
        }

        // On clearance signals, clean up previous active banners from Notification Center
        if item.eventType == .threatClear {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["sirenua_threat_\(item.regionName)"])
        } else if item.eventType == .clear {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["sirenua_alarm_\(item.regionName)"])
        }

        // Haptic feedback is handled by willPresent delegate (fires for ALL foreground notifications,
        // both local and remote). Not triggered here to avoid double vibration.

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                notifLogger.error("Notification scheduling failed: \(error.localizedDescription)")
            }
            // 1-second spacing between sequential banners
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isProcessingQueue = false
                self.processQueue()
            }
        }
    }
}
