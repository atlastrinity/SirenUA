import Foundation
import UserNotifications
import AVFoundation

class NotificationManager {
    static let shared = NotificationManager()
    private var audioPlayer: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private init() {}

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
    
    func speakText(_ text: String) {
        guard notificationsEnabled else { return }
        // Зупиняємо попереднє мовлення, якщо воно триває
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "uk-UA")
        utterance.rate = 0.5 // Швидкість мовлення (дефолт 0.5 - нормальний темп)
        utterance.volume = 1.0
        
        // Додамо невелику паузу перед початком
        utterance.preUtteranceDelay = 0.5
        
        speechSynthesizer.speak(utterance)
        print("Speaking: \(text)")
    }
    
    private func playSound(named filename: String, for regionName: String) {
        guard notificationsEnabled else { return }
        guard shouldNotify(for: regionName) else { return }
        
        let useVoice = UserDefaults.standard.object(forKey: "premiumUseVoiceAnnouncements") as? Bool ?? true
        
        if useVoice {
            // Озвучуємо подію голосом залежно від типу файлу
            let isClear = filename.contains("vidbiy")
            let speechMsg = isClear ? 
                "Увага! Відбій повітряної тривоги в \(regionName)." : 
                "Увага! Повітряна тривога в \(regionName). Прямуйте в укриття!"
            
            speakText(speechMsg)
        }
        
        // Відтворюємо звук у фоновому потоці
        DispatchQueue.global(qos: .userInitiated).async {
            guard let path = Bundle.main.path(forResource: filename, ofType: nil) else {
                print("Audio file not found: \(filename)")
                return
            }
            let url = URL(fileURLWithPath: path)
            do {
                #if os(iOS)
                // Налаштовуємо аудіосесію для iOS
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
        // Програємо звук безпосередньо в додатку
        playSound(named: "siren.wav", for: regionName)
        
        guard notificationsEnabled else { return }
        guard shouldNotify(for: regionName) else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Повітряна тривога в: \(regionName). Прямуйте в укриття!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("siren.wav"))
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // nil trigger means "deliver immediately"
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func sendClearNotification(for regionName: String) {
        // Програємо звук безпосередньо в додатку
        playSound(named: "vidbiy.wav", for: regionName)
        
        guard notificationsEnabled else { return }
        guard shouldNotify(for: regionName) else { return }
        let content = UNMutableNotificationContent()
        content.title = "🟢 Відбій тривоги!"
        content.body = "Відбій повітряної тривоги в: \(regionName)."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("vidbiy.wav"))
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
}

