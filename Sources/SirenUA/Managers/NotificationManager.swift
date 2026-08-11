import Foundation
import UserNotifications
import AudioToolbox
import UIKit
import FirebaseMessaging
import OSLog

private let notifLogger = Logger(subsystem: "com.sirenua", category: "Notifications")

// MARK: - PendingNotification

struct PendingNotification {
    let title: String
    let body: String
    let soundName: String
    let interruptionLevel: UNNotificationInterruptionLevel
    let relevanceScore: Double
    let isCritical: Bool
    let regionName: String
}

// MARK: - NotificationManager

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = NotificationManager()

    /// Track the region name when user taps a push notification
    var pendingTappedRegion: String? = nil

    /// Serial queue for notification delivery to prevent overlap
    private var notificationQueue: [PendingNotification] = []
    private var isProcessingQueue = false

    /// Sound throttle: prevent notification sounds from overlapping
    /// Reduced from 20s to 10s for critical alerts (ballistic can require rapid notifications)
    private var lastPlayedTime: Date?
    private static let soundThrottleCritical: TimeInterval = 10.0
    private static let soundThrottleNormal: TimeInterval = 20.0
    
    /// Runtime detection: does the app have Critical Alerts entitlement approved by Apple?
    /// If false, we fallback to .timeSensitive which still bypasses Focus mode.
    private(set) var hasCriticalAlerts: Bool = false

    // MARK: - Init

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Authorization

    func requestAuthorization() {
        guard NotificationSettings.shared.isNotificationsEnabled else { return }
        
        // First, try requesting WITH criticalAlert
        // This will succeed only if the entitlement is provisioned by Apple
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .criticalAlert]) { [weak self] granted, error in
            if let error {
                // criticalAlert not available — fallback to standard + timeSensitive
                notifLogger.warning("Critical alert request failed (expected without entitlement): \(error.localizedDescription)")
                notifLogger.info("Falling back to .timeSensitive for DND bypass")
                self?.hasCriticalAlerts = false
                
                // Re-request without criticalAlert
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, err in
                    if let err {
                        notifLogger.error("Fallback permission request error: \(err.localizedDescription)")
                    } else {
                        notifLogger.info("Notification permission (standard): \(granted ? "granted" : "denied")")
                    }
                }
            } else {
                if granted {
                    notifLogger.info("✅ Critical Alerts permission GRANTED — full DND bypass enabled")
                    self?.hasCriticalAlerts = true
                } else {
                    notifLogger.info("Notification permission denied by user")
                    self?.hasCriticalAlerts = false
                }
            }
            
            // Check actual authorization status to confirm critical alerts
            UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                let criticalEnabled = settings.criticalAlertSetting == .enabled
                self?.hasCriticalAlerts = criticalEnabled
                notifLogger.info("Critical alerts status: \(criticalEnabled ? "ENABLED" : "NOT AVAILABLE")")
                notifLogger.info("Time sensitive status: \(settings.timeSensitiveSetting == .enabled ? "ENABLED" : "NOT AVAILABLE")")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

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

            let title = notification.request.content.title.lowercased()
            let body = notification.request.content.body.lowercased()

            let isThreat = title.contains("⚠️") || title.contains("загроза") || title.contains("шахед") || title.contains("ракета") || title.contains("каб") || title.contains("бпла") || title.contains("балистика") || body.contains("загроза") || body.contains("шахед") || body.contains("ракета") || body.contains("каб")
            let isClear = title.contains("🟢") || title.contains("відбій") || body.contains("відбій")
            let isAlarm = title.contains("🚨") || title.contains("тривога") || body.contains("тривога")

            let shouldPlaySound: Bool
            if isThreat {
                shouldPlaySound = NotificationSettings.shared.shouldPlayThreatSound
            } else if isClear {
                shouldPlaySound = NotificationSettings.shared.shouldPlayClearSound
            } else if isAlarm {
                shouldPlaySound = NotificationSettings.shared.shouldPlayAlarmSound
            } else {
                shouldPlaySound = NotificationSettings.shared.shouldPlayAlarmSound
            }

            let interruptionLevel = notification.request.content.interruptionLevel
            let isCriticalNotif = interruptionLevel == .critical || interruptionLevel == .timeSensitive
            let throttle = isCriticalNotif ? Self.soundThrottleCritical : Self.soundThrottleNormal
            
            let now = Date()
            if NotificationSettings.shared.shouldVibrate {
                self.triggerHaptic(isAlarm ? .error : (isClear ? .success : .warning), pulses: isAlarm ? 4 : (isClear ? 2 : 3))
            }

            if !shouldPlaySound {
                notifLogger.info("Foreground notification sound suppressed by user settings")
                completionHandler([.banner, .badge, .list])
            } else if let last = self.lastPlayedTime, now.timeIntervalSince(last) < throttle {
                notifLogger.debug("Foreground notification sound suppressed (within \(throttle)s)")
                completionHandler([.banner, .badge, .list])
            } else if notification.request.content.sound != nil {
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

    private var syncTask: Task<Void, Never>? = nil

    func syncTopicSubscriptions() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.syncTask?.cancel()
            self.syncTask = Task {
                // Debounce: wait 0.5 seconds for subsequent settings updates
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                
                let notifsEnabled = NotificationSettings.shared.notificationsEnabled

                for (region, topic) in RegionRegistry.topicMapping {
                    let shouldSubscribe = notifsEnabled && NotificationSettings.shared.isTracked(region)
                    if shouldSubscribe {
                        do {
                            try await Messaging.messaging().subscribe(toTopic: topic)
                            notifLogger.debug("Subscribed to \(topic)")
                        } catch {
                            notifLogger.warning("Subscribe to \(topic) failed: \(error.localizedDescription)")
                        }
                    } else {
                        do {
                            try await Messaging.messaging().unsubscribe(fromTopic: topic)
                            notifLogger.debug("Unsubscribed from \(topic)")
                        } catch {
                            notifLogger.warning("Unsubscribe from \(topic) failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Public API

    func sendAlertNotification(for regionName: String, title: String = "🚨 Увага! Повітряна тривога!") {
        let body = "Повітряна тривога в: \(regionName). Прямуйте в укриття!"

        // criticalAlertsEnabled тепер означає "пробиває DND" (.timeSensitive), а не iOS Critical Alert
        let shouldBypassDND = NotificationSettings.shared.isCriticalAlertsEnabled
        let level: UNNotificationInterruptionLevel = shouldBypassDND ? .timeSensitive : .active

        let fullTitle = "🚨 Повітряна тривога — \(regionName)"
        let soundName = NotificationSettings.shared.shouldPlayAlarmSound ? "siren.wav" : ""

        enqueue(title: fullTitle, body: body, soundName: soundName, regionName: regionName,
                interruptionLevel: level, relevanceScore: 1.0, isCritical: false)

        triggerHaptic(.warning, pulses: 4)
    }

    func sendThreatNotification(for regionName: String, title: String, body: String,
                                confidence: Int = 75, isCritical: Bool = false) {
        let effectiveTimeSensitive = isCritical && NotificationSettings.shared.isCriticalAlertsEnabled
        let level: UNNotificationInterruptionLevel
        let relevance: Double

        if effectiveTimeSensitive || confidence >= 85 {
            level = .timeSensitive
            relevance = 0.8
        } else if confidence >= 60 {
            level = .timeSensitive
            relevance = 0.6
        } else {
            level = .active
            relevance = 0.4
        }

        let soundName = NotificationSettings.shared.shouldPlayThreatSound ? (isCritical ? "siren.wav" : "warning.wav") : ""

        var fullTitle = title
        if !title.contains(regionName) {
            fullTitle = "\(title) — \(regionName)"
        }

        enqueue(title: fullTitle, body: body, soundName: soundName, regionName: regionName,
                interruptionLevel: level, relevanceScore: relevance, isCritical: false)

        triggerHaptic(confidence >= 85 ? .error : .warning, pulses: 3)
    }

    func sendClearNotification(for regionName: String) {
        let title = "🟢 Відбій тривоги — \(regionName)"
        let body  = "Відбій повітряної тривоги в: \(regionName)."
        let soundName = NotificationSettings.shared.shouldPlayClearSound ? "vidbiy.wav" : ""

        let shouldBypassDND = NotificationSettings.shared.isCriticalAlertsEnabled
        let level: UNNotificationInterruptionLevel = shouldBypassDND ? .timeSensitive : .active

        enqueue(title: title, body: body, soundName: soundName, regionName: regionName,
                interruptionLevel: level, relevanceScore: 0.3, isCritical: false)

        triggerHaptic(.success, pulses: 2)
    }

    // MARK: - Private helpers

    private func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType, pulses: Int = 3) {
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

    private func enqueue(title: String, body: String, soundName: String, regionName: String,
                         interruptionLevel: UNNotificationInterruptionLevel = .active,
                         relevanceScore: Double = 0.5, isCritical: Bool = false) {
        guard NotificationSettings.shared.isNotificationsEnabled else { return }
        guard NotificationSettings.shared.isTracked(regionName) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let now = Date()
            let throttle = isCritical ? Self.soundThrottleCritical : Self.soundThrottleNormal
            let playSoundForThis: Bool
            if soundName.isEmpty {
                playSoundForThis = false
            } else if let last = self.lastPlayedTime, now.timeIntervalSince(last) < throttle {
                playSoundForThis = false
                notifLogger.debug("Notification sound for \(regionName) throttled (within \(throttle)s)")
            } else {
                playSoundForThis = true
                self.lastPlayedTime = now
            }

            if playSoundForThis {
                SoundPlayerManager.shared.playSound(named: soundName)
            }

            self.notificationQueue.append(PendingNotification(
                            title: title,
                            body: body,
                            soundName: playSoundForThis ? soundName : "",
                            interruptionLevel: interruptionLevel,
                            relevanceScore: relevanceScore,
                            isCritical: isCritical,
                            regionName: regionName
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
                content.userInfo  = ["region": item.regionName]

                // Interruption level for lock screen / Focus delivery
        content.interruptionLevel = item.interruptionLevel
        content.relevanceScore = item.relevanceScore
        
        // Sound: always use named sound file, never defaultCritical
        // The server no longer sends critical push, so we handle sound purely client-side
        if !item.soundName.isEmpty {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(item.soundName))
        } else {
            content.sound = nil
        }

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

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
