#if os(iOS)
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Конфігурація Firebase
        FirebaseApp.configure()
        
        // Встановлюємо делегат для повідомлень Firebase
        Messaging.messaging().delegate = self
        
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
    
    // Обробка оновлення токена реєстрації FCM
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM Registration Token: \(String(describing: fcmToken))")
        // Синхронізуємо підписки при отриманні токена
        NotificationManager.shared.syncTopicSubscriptions()
    }
}
#endif
