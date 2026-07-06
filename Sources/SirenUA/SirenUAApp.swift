import SwiftUI

@main
@available(iOS 17.0, *)
struct SirenUAApp: App {
    init() {
        UserDefaults.standard.register(defaults: [
            "notificationsEnabled": true,
            "autoRefreshEnabled": true,
            "refreshInterval": 30,
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
