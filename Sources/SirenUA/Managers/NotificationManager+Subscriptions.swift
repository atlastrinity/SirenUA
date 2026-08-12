import Foundation
import FirebaseMessaging
import OSLog

// MARK: - Topic Subscriptions

extension NotificationManager {

    func syncTopicSubscriptions() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.syncTask?.cancel()
            self.syncTask = Task {
                guard !Task.isCancelled else { return }
                
                let notifsEnabled = NotificationSettings.shared.notificationsEnabled

                await withTaskGroup(of: Void.self) { group in
                    for (region, topic) in RegionRegistry.topicMapping {
                        if RegionRegistry.isPermanentlyActive(region) {
                            continue
                        }
                        let shouldSubscribe = notifsEnabled && NotificationSettings.shared.isTracked(region)
                        group.addTask {
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
        }
    }
}
