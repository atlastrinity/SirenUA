import Foundation
import UserNotifications
import AVFoundation
import FirebaseMessaging
import OSLog

private let notifLogger = Logger(subsystem: "com.sirenua", category: "Notifications")

// MARK: - PendingNotification

struct PendingNotification {
    let title: String
    let body: String
    let soundName: String
}

// MARK: - NotificationManager

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = NotificationManager()

    private var audioPlayer: AVAudioPlayer?

    /// Serial queue for notification delivery to prevent overlap
    private var notificationQueue: [PendingNotification] = []
    private var isProcessingQueue = false

    /// Sound throttle: prevent the same sound from overlapping within 8 seconds
    private var lastPlayedTimes: [String: Date] = [:]
    private static let soundThrottle: TimeInterval = 8.0

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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                notifLogger.error("Permission request error: \(error.localizedDescription)")
            } else {
                notifLogger.info("Notification permission: \(granted ? "granted" : "denied")")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
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
                
                let allTracked = UserDefaults.standard.bool(forKey: "allRegionsTracked")
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
        enqueue(title: title, body: body, soundName: "siren.wav", regionName: regionName)
    }

    func sendThreatNotification(for regionName: String, title: String, body: String) {
        enqueue(title: title, body: body, soundName: "warning.wav", regionName: regionName)
    }

    func sendClearNotification(for regionName: String) {
        let title = "🟢 Відбій тривоги!"
        let body  = "Відбій повітряної тривоги в: \(regionName)."
        enqueue(title: title, body: body, soundName: "vidbiy.wav", regionName: regionName)
    }

    // MARK: - Private helpers

    private var notificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
    }

    private func shouldNotify(for regionName: String) -> Bool {
        let allTracked = UserDefaults.standard.object(forKey: "allRegionsTracked") as? Bool ?? true
        if allTracked { return true }
        let tracked = UserDefaults.standard.string(forKey: "trackedRegionsString") ?? ""
        return tracked.components(separatedBy: ";").contains(regionName)
    }

    private func enqueue(title: String, body: String, soundName: String, regionName: String) {
        guard notificationsEnabled else { return }
        guard shouldNotify(for: regionName) else { return }

        playSound(named: soundName, for: regionName)

        DispatchQueue.main.async {
            self.notificationQueue.append(PendingNotification(title: title, body: body, soundName: soundName))
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
        content.sound     = UNNotificationSound(named: UNNotificationSoundName(item.soundName))

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
        guard notificationsEnabled, shouldNotify(for: regionName) else { return }

        let now = Date()
        if let last = lastPlayedTimes[filename], now.timeIntervalSince(last) < Self.soundThrottle {
            notifLogger.debug("Sound \(filename) throttled")
            return
        }
        lastPlayedTimes[filename] = now

        DispatchQueue.global(qos: .userInitiated).async {
            guard let path = Bundle.main.path(forResource: filename, ofType: nil) else {
                notifLogger.warning("Audio file not found: \(filename)")
                return
            }
            let url = URL(fileURLWithPath: path)
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.play()
                notifLogger.info("Playing audio: \(filename)")
            } catch {
                notifLogger.error("Audio player error: \(error.localizedDescription)")
            }
        }
    }
}
