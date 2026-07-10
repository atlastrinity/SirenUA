import SwiftUI

@main
struct SirenUAApp: App {
#if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
#endif
    
    init() {
        UserDefaults.standard.register(defaults: [
            "notificationsEnabled": true,
            "autoRefreshEnabled": true,
            "showRadar": true,
            "mapType": 0,
            "searchRadius": 3.0
        ])
    }

    @StateObject private var storeManager = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storeManager)
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                }
        }
    }
}
