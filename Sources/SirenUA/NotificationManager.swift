import Foundation
import UserNotifications
import AVFoundation

struct PendingNotification {
    let title: String
    let body: String
    let soundName: String
}

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private var audioPlayer: AVAudioPlayer?
    
    // Черга для послідовного виведення пуш-сповіщень
    private var notificationQueue: [PendingNotification] = []
    private var isProcessingQueue = false
    
    // Трекер часу програвання звуків для запобігання накладанню
    private var lastPlayedTimes: [String: Date] = [:]
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // Дозволяємо показ пуш-сповіщень, навіть коли додаток відкритий
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    private var notificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
    }

    private func shouldNotify(for regionName: String) -> Bool {
        let allTracked = UserDefaults.standard.object(forKey: "allRegionsTracked") as? Bool ?? true
        if allTracked {
            return true
        }
        let trackedString = UserDefaults.standard.object(forKey: "trackedRegionsString") as? String ?? ""
        let trackedList = trackedString.components(separatedBy: ";")
        return trackedList.contains(regionName)
    }
    
    func requestAuthorization() {
        guard notificationsEnabled else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    // Чергування та послідовне відправлення пушів
    private func enqueueNotification(title: String, body: String, soundName: String, regionName: String) {
        guard notificationsEnabled else { return }
        guard shouldNotify(for: regionName) else { return }
        
        // Відтворюємо звук (буде відтворюватися тільки один раз на партію завдяки ліміту)
        playSound(named: soundName, for: regionName)
        
        let pending = PendingNotification(title: title, body: body, soundName: soundName)
        
        DispatchQueue.main.async {
            self.notificationQueue.append(pending)
            self.processNotificationQueue()
        }
    }
    
    private func processNotificationQueue() {
        guard !isProcessingQueue else { return }
        guard !notificationQueue.isEmpty else { return }
        
        isProcessingQueue = true
        let notification = notificationQueue.removeFirst()
        
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = UNNotificationSound(named: UNNotificationSoundName(notification.soundName))
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling queued notification: \(error.localizedDescription)")
            }
            
            // Затримка в 1.0 секунду перед наступним пушем для послідовного спливання
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isProcessingQueue = false
                self.processNotificationQueue()
            }
        }
    }
    
    private func playSound(named filename: String, for regionName: String) {
        guard notificationsEnabled else { return }
        guard shouldNotify(for: regionName) else { return }
        
        let now = Date()
        // Ліміт накладання звуків: якщо такий самий звук програвався менше ніж 8.0 секунд тому — ігноруємо
        if let lastPlayed = lastPlayedTimes[filename], now.timeIntervalSince(lastPlayed) < 8.0 {
            print("Skipping sound \(filename) (throttled to avoid overlaps)")
            return
        }
        lastPlayedTimes[filename] = now
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let path = Bundle.main.path(forResource: filename, ofType: nil) else {
                print("Audio file not found: \(filename)")
                return
            }
            let url = URL(fileURLWithPath: path)
            do {
                #if os(iOS)
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
                #endif
                
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.play()
                print("Playing audio: \(filename)")
            } catch {
                print("Audio player error: \(error.localizedDescription)")
            }
        }
    }
    
    func sendAlertNotification(for regionName: String, title: String = "🚨 Увага! Повітряна тривога!") {
        let body = "Повітряна тривога в: \(regionName). Прямуйте в укриття!"
        enqueueNotification(title: title, body: body, soundName: "siren.wav", regionName: regionName)
    }
    
    func sendThreatNotification(for regionName: String, title: String, body: String) {
        enqueueNotification(title: title, body: body, soundName: "warning.wav", regionName: regionName)
    }
    
    func sendClearNotification(for regionName: String) {
        let title = "🟢 Відбій тривоги!"
        let body = "Відбій повітряної тривоги в: \(regionName)."
        enqueueNotification(title: title, body: body, soundName: "vidbiy.wav", regionName: regionName)
    }
}

