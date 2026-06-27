import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func sendAlertNotification(for regionName: String, title: String = "🚨 Увага! Повітряна тривога!") {
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
