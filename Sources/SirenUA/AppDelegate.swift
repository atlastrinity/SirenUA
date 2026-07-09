#if os(iOS)
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Конфігурація Firebase
        FirebaseApp.configure()
        
        // Встановлюємо делегат для повідомлень Firebase
        Messaging.messaging().delegate = self
        
        // Встановлюємо делегат для обробки пушів у foreground
        UNUserNotificationCenter.current().delegate = self
        
        // Реєстрація для віддалених пушів
        application.registerForRemoteNotifications()
        
        return true
    }
    
    // Передаємо токен APNs до Firebase
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // Обробка FCM data push — тригерить оновлення UI через NotificationCenter
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // FCM data payload містить threat data — сигналізуємо ViewModel оновити стан
        if userInfo["threat_level"] != nil || userInfo["region"] != nil {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("ThreatDataUpdated"), object: nil, userInfo: userInfo)
            }
        }
        completionHandler(.newData)
    }
    
    // Обробка оновлення токена реєстрації FCM
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM Registration Token: \(String(describing: fcmToken))")
        // Синхронізуємо підписки при отриманні токена
        NotificationManager.shared.syncTopicSubscriptions()
    }
    
    // Показувати пуш-сповіщення навіть коли додаток на екрані (foreground)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
#endif
