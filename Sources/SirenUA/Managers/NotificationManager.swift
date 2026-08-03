import Foundation
import UserNotifications
import AVFoundation
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

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, AVAudioPlayerDelegate, @unchecked Sendable {

    static let shared = NotificationManager()

        /// Track the region name when user taps a push notification
        var pendingTappedRegion: String? = nil

        private var audioPlayer: AVAudioPlayer?
        private var audioPlaybackQueue: [URL] = []
        private var isAudioPlaying: Bool = false
        private let audioQueueLock = NSLock()

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

    // MARK: - Firebase Topic Mapping

    private let topicMapping: [String: String] = [
        "Вінницька область":        "region_vinnytsia",
        "Волинська область":         "region_volyn",
        "Дніпропетровська область":  "region_dnipro",
        "Донецька область":          "region_donetsk",
        "Житомирська область":       "region_zhytomyr",
        "Закарпатська область":      "region_zakarpattya",
        "Запорізька область":        "region_zaporizhzhya",
        "Івано-Франківська область": "region_if",
        "Київська область":          "region_kyiv_oblast",
        "м. Київ":                   "region_kyiv_city",
        "Кіровоградська область":    "region_kirovohrad",
        "Луганська область":         "region_luhansk",
        "Львівська область":         "region_lviv",
        "Миколаївська область":      "region_mykolaiv",
        "Одеська область":           "region_odesa",
        "Полтавська область":        "region_poltava",
        "Рівненська область":        "region_rivne",
        "Сумська область":           "region_sumy",
        "Тернопільська область":     "region_ternopil",
        "Харківська область":        "region_kharkiv",
        "Херсонська область":        "region_kherson",
        "Хмельницька область":       "region_khmelnytskyi",
        "Черкаська область":         "region_cherkasy",
        "Чернівецька область":       "region_chernivtsi",
        "Чернігівська область":      "region_chernihiv"
    ]

    // MARK: - Init

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Authorization

    func requestAuthorization() {
        guard notificationsEnabled else { return }
        
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
            let userInfo = notification.request.content.userInfo
            var regionName: String? = userInfo["region"] as? String ?? userInfo["regionName"] as? String
            if regionName == nil, let aps = userInfo["aps"] as? [String: Any],
               let custom = aps["custom_data"] as? [String: Any] {
                regionName = custom["region"] as? String
            }
            if let region = regionName, !self.shouldNotify(for: region) {
                completionHandler([])
                return
            }

            let interruptionLevel = notification.request.content.interruptionLevel
            let isCriticalNotif = interruptionLevel == .critical || interruptionLevel == .timeSensitive
            let throttle = isCriticalNotif ? Self.soundThrottleCritical : Self.soundThrottleNormal
            
            let now = Date()
            if let last = self.lastPlayedTime, now.timeIntervalSince(last) < throttle {
                notifLogger.debug("Foreground notification sound suppressed (within \(throttle)s)")
                completionHandler([.banner, .badge, .list])
            } else {
                if notification.request.content.sound != nil {
                    self.lastPlayedTime = now
                }
                completionHandler([.banner, .sound, .badge, .list])
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
                
                let allTracked = UserDefaults.standard.object(forKey: "allRegionsTracked") as? Bool ?? true
                let trackedString = UserDefaults.standard.string(forKey: "trackedRegionsString") ?? ""
                let trackedList = Set(trackedString.components(separatedBy: ";").filter { !$0.isEmpty })

                for (region, topic) in self.topicMapping {
                    let shouldSubscribe = allTracked || trackedList.contains(region)
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

        // Use .critical if entitled and enabled by user, otherwise .timeSensitive
        let isCrit = hasCriticalAlerts && criticalAlertsEnabled
        let level: UNNotificationInterruptionLevel = isCrit ? .critical : .timeSensitive

        let fullTitle = "🚨 Повітряна тривога — \(regionName)"
        let soundName = muteAlarmsSound ? "" : "siren.wav"

        enqueue(title: fullTitle, body: body, soundName: soundName, regionName: regionName,
                interruptionLevel: level, relevanceScore: 1.0, isCritical: isCrit)

        // Haptic feedback for official alarm
        triggerHaptic(.warning, pulses: 4)
        if isCrit, #available(iOS 16.0, *) {
            CriticalAlertManager.shared.sendCriticalAlert(region: regionName, isActive: true)
        }
    }

    func sendThreatNotification(for regionName: String, title: String, body: String,
                                confidence: Int = 75, isCritical: Bool = false) {
        let effectiveIsCritical = isCritical && criticalAlertsEnabled
        let level: UNNotificationInterruptionLevel
        let relevance: Double

        if effectiveIsCritical || confidence >= 85 {
            level = .timeSensitive  // Pierces Focus, but not DND without entitlement
            relevance = 0.8
        } else if confidence >= 60 {
            level = .timeSensitive
            relevance = 0.6
        } else {
            level = .active
            relevance = 0.4
        }

        let soundName = muteThreatsSound ? "" : (effectiveIsCritical ? "siren.wav" : "warning.wav")

        var fullTitle = title
        if !title.contains(regionName) {
            fullTitle = "\(title) — \(regionName)"
        }

        enqueue(title: fullTitle, body: body, soundName: soundName, regionName: regionName,
                interruptionLevel: level, relevanceScore: relevance, isCritical: effectiveIsCritical)

        // Haptic feedback for threat detection (stronger multi-pulse for high confidence)
        triggerHaptic(confidence >= 85 ? .error : .warning, pulses: 3)
    }

    func sendClearNotification(for regionName: String) {
        let title = "🟢 Відбій тривоги — \(regionName)"
        let body  = "Відбій повітряної тривоги в: \(regionName)."
        let soundName = muteClearSound ? "" : "vidbiy.wav"

        enqueue(title: title, body: body, soundName: soundName, regionName: regionName,
                interruptionLevel: .active, relevanceScore: 0.3, isCritical: false)

        // Haptic feedback for alert clearance
        triggerHaptic(.success, pulses: 2)
    }

    // MARK: - Private helpers

    private var notificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
    }

    private var criticalAlertsEnabled: Bool {
        UserDefaults.standard.object(forKey: "criticalAlertsEnabled") as? Bool ?? true
    }

    private var muteAlarmsSound: Bool {
        UserDefaults.standard.bool(forKey: "muteAlarmsSound")
    }

    private var muteThreatsSound: Bool {
        UserDefaults.standard.bool(forKey: "muteThreatsSound")
    }

    private var muteClearSound: Bool {
        UserDefaults.standard.bool(forKey: "muteClearSound")
    }

    private var vibrationEnabled: Bool {
        UserDefaults.standard.object(forKey: "vibrationEnabled") as? Bool ?? true
    }

    /// Triggers distinct multi-pulse haptic feedback for alert events based on severity.
    /// - Parameters:
    ///   - type: .warning for alarms, .success for clears, .error for critical threats
    ///   - pulses: Number of distinct vibration pulses (default 3)
    private func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType, pulses: Int = 3) {
        guard vibrationEnabled else { return }
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

    private func shouldNotify(for regionName: String) -> Bool {
        let allTracked = UserDefaults.standard.object(forKey: "allRegionsTracked") as? Bool ?? true
        if allTracked { return true }
        let tracked = UserDefaults.standard.string(forKey: "trackedRegionsString") ?? ""
        return tracked.components(separatedBy: ";").contains(regionName)
    }

    private func enqueue(title: String, body: String, soundName: String, regionName: String,
                         interruptionLevel: UNNotificationInterruptionLevel = .active,
                         relevanceScore: Double = 0.5, isCritical: Bool = false) {
        guard notificationsEnabled else { return }
        guard shouldNotify(for: regionName) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let now = Date()
            let throttle = isCritical ? Self.soundThrottleCritical : Self.soundThrottleNormal
            let playSoundForThis: Bool
            if let last = self.lastPlayedTime, now.timeIntervalSince(last) < throttle {
                playSoundForThis = false
                notifLogger.debug("Notification sound for \(regionName) throttled (within \(throttle)s)")
            } else {
                playSoundForThis = true
                self.lastPlayedTime = now
            }

            if playSoundForThis {
                self.playSound(named: soundName, for: regionName)
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
        
        // Sound configuration: set custom/critical sound if not muted, or nil if muted
        if !item.soundName.isEmpty {
            if item.isCritical {
                content.sound = UNNotificationSound.defaultCritical
            } else {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(item.soundName))
            }
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

    private func playSound(named filename: String, for regionName: String) {
        guard !filename.isEmpty else { return }
        guard notificationsEnabled, shouldNotify(for: regionName) else { return }

        guard let path = Bundle.main.path(forResource: filename, ofType: nil) else {
            notifLogger.warning("Audio file not found: \(filename)")
            return
        }
        let url = URL(fileURLWithPath: path)

        audioQueueLock.lock()
        audioPlaybackQueue.append(url)
        let shouldStart = !isAudioPlaying
        audioQueueLock.unlock()

        if shouldStart {
            playNextAudioInQueue()
        }
    }

    private func playNextAudioInQueue() {
        audioQueueLock.lock()
        guard !audioPlaybackQueue.isEmpty else {
            isAudioPlaying = false
            audioQueueLock.unlock()
            return
        }
        let nextUrl = audioPlaybackQueue.removeFirst()
        isAudioPlaying = true
        audioQueueLock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                let player = try AVAudioPlayer(contentsOf: nextUrl)
                player.delegate = self
                self.audioPlayer = player
                player.play()
                notifLogger.info("Playing queued audio: \(nextUrl.lastPathComponent)")
            } catch {
                notifLogger.error("Audio player error: \(error.localizedDescription)")
                self.audioQueueLock.lock()
                self.isAudioPlaying = false
                self.audioQueueLock.unlock()
                self.playNextAudioInQueue()
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            NotificationManager.shared.audioQueueLock.lock()
            NotificationManager.shared.isAudioPlaying = false
            NotificationManager.shared.audioQueueLock.unlock()
            NotificationManager.shared.playNextAudioInQueue()
        }
    }
}
