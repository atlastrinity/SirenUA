import SwiftUI

@main
@available(iOS 16.0, *)
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
            Group {
                if #available(iOS 17.0, *) {
                    ContentView()
                } else {
                    iOS16FallbackView()
                }
            }
            .environmentObject(storeManager)
            .onAppear {
                NotificationManager.shared.requestAuthorization()
            }
        }
    }
}
