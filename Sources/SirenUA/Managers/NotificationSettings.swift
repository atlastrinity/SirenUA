import Foundation
import Combine
import SwiftUI
import OSLog

private let settingsLogger = Logger(subsystem: "com.sirenua", category: "NotificationSettings")

// MARK: - NotificationSettings

final class NotificationSettings: ObservableObject, @unchecked Sendable {
    static let shared = NotificationSettings()

    // MARK: Keys
    enum Keys {
        static let notificationsEnabled = "notificationsEnabled"
        static let criticalAlertsEnabled = "criticalAlertsEnabled"
        static let muteAlarmsSound = "muteAlarmsSound"
        static let muteThreatsSound = "muteThreatsSound"
        static let muteClearSound = "muteClearSound"
        static let vibrationEnabled = "vibrationEnabled"
        static let allRegionsTracked = "allRegionsTracked"
        static let trackedRegionsString = "trackedRegionsString"
    }

    // MARK: Published Properties
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
            settingsLogger.info("notificationsEnabled changed: \(self.notificationsEnabled)")
            NotificationManager.shared.syncTopicSubscriptions()
        }
    }

    @Published var criticalAlertsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(criticalAlertsEnabled, forKey: Keys.criticalAlertsEnabled)
            settingsLogger.info("criticalAlertsEnabled changed: \(self.criticalAlertsEnabled)")
        }
    }

    @Published var muteAlarmsSound: Bool {
        didSet {
            UserDefaults.standard.set(muteAlarmsSound, forKey: Keys.muteAlarmsSound)
            settingsLogger.info("muteAlarmsSound changed: \(self.muteAlarmsSound)")
        }
    }

    @Published var muteThreatsSound: Bool {
        didSet {
            UserDefaults.standard.set(muteThreatsSound, forKey: Keys.muteThreatsSound)
            settingsLogger.info("muteThreatsSound changed: \(self.muteThreatsSound)")
        }
    }

    @Published var muteClearSound: Bool {
        didSet {
            UserDefaults.standard.set(muteClearSound, forKey: Keys.muteClearSound)
            settingsLogger.info("muteClearSound changed: \(self.muteClearSound)")
        }
    }

    @Published var vibrationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(vibrationEnabled, forKey: Keys.vibrationEnabled)
            settingsLogger.info("vibrationEnabled changed: \(self.vibrationEnabled)")
        }
    }

    @Published var allRegionsTracked: Bool {
        didSet {
            UserDefaults.standard.set(allRegionsTracked, forKey: Keys.allRegionsTracked)
            NotificationManager.shared.syncTopicSubscriptions()
        }
    }

    @Published var trackedRegionsString: String {
        didSet {
            UserDefaults.standard.set(trackedRegionsString, forKey: Keys.trackedRegionsString)
            NotificationManager.shared.syncTopicSubscriptions()
        }
    }

    // MARK: Init
    nonisolated private init() {
        let defaults = UserDefaults.standard
        self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        self.criticalAlertsEnabled = defaults.object(forKey: Keys.criticalAlertsEnabled) as? Bool ?? true
        self.muteAlarmsSound = defaults.bool(forKey: Keys.muteAlarmsSound)
        self.muteThreatsSound = defaults.bool(forKey: Keys.muteThreatsSound)
        self.muteClearSound = defaults.bool(forKey: Keys.muteClearSound)
        self.vibrationEnabled = defaults.object(forKey: Keys.vibrationEnabled) as? Bool ?? true
        self.allRegionsTracked = defaults.object(forKey: Keys.allRegionsTracked) as? Bool ?? true
        self.trackedRegionsString = defaults.string(forKey: Keys.trackedRegionsString) ?? ""
    }

    // MARK: Nonisolated Thread-Safe Getters (Accessible from background threads / NotificationManager)

    nonisolated var isNotificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
    }

    nonisolated var isCriticalAlertsEnabled: Bool {
        UserDefaults.standard.object(forKey: Keys.criticalAlertsEnabled) as? Bool ?? true
    }

    nonisolated var isMuteAlarmsSound: Bool {
        UserDefaults.standard.bool(forKey: Keys.muteAlarmsSound)
    }

    nonisolated var isMuteThreatsSound: Bool {
        UserDefaults.standard.bool(forKey: Keys.muteThreatsSound)
    }

    nonisolated var isMuteClearSound: Bool {
        UserDefaults.standard.bool(forKey: Keys.muteClearSound)
    }

    nonisolated var isVibrationEnabled: Bool {
        UserDefaults.standard.object(forKey: Keys.vibrationEnabled) as? Bool ?? true
    }

    nonisolated var shouldPlayAlarmSound: Bool {
        isNotificationsEnabled && !isMuteAlarmsSound
    }

    nonisolated var shouldPlayThreatSound: Bool {
        isNotificationsEnabled && !isMuteThreatsSound
    }

    nonisolated var shouldPlayClearSound: Bool {
        isNotificationsEnabled && !isMuteClearSound
    }

    nonisolated var shouldVibrate: Bool {
        isNotificationsEnabled && isVibrationEnabled
    }

    nonisolated func isTracked(_ regionName: String) -> Bool {
        let allTracked = UserDefaults.standard.object(forKey: Keys.allRegionsTracked) as? Bool ?? true
        guard !allTracked else { return true }
        let trackedString = UserDefaults.standard.string(forKey: Keys.trackedRegionsString) ?? ""
        guard !trackedString.isEmpty else { return true }
        let trackedList = trackedString.components(separatedBy: ";").filter { !$0.isEmpty }
        return trackedList.contains(regionName)
    }

    func setTracked(_ regionName: String, isOn: Bool) {
        var list = trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }
        if isOn {
            if !list.contains(regionName) { list.append(regionName) }
        } else {
            list.removeAll { $0 == regionName }
        }
        trackedRegionsString = list.joined(separator: ";")
    }
}
