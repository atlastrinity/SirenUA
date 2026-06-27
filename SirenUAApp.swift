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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                }
        }
    }
}
