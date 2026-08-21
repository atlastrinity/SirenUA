import Foundation
import Combine
import SwiftUI
import OSLog

private let settingsLogger = Logger(subsystem: "com.sirenua", category: "NotificationSettings")

// MARK: - NotificationSettings

/// Центральне сховище налаштувань сповіщень та відстежуваних регіонів.
///
/// Архітектура: сервер надсилає однаковий потік подій для всіх регіонів,
/// а клієнт самостійно фільтрує їх на основі цих налаштувань:
///
/// **6 тогглів сповіщень:**
/// 1. `notificationsEnabled` — головний вимикач push-повідомлень
/// 2. `criticalAlertsEnabled` — пробивання режиму «Не турбувати» (.timeSensitive / .critical)
/// 3. `muteAlarmsSound` — вимкнення звуку для офіційних тривог
/// 4. `muteThreatsSound` — вимкнення звуку для ШІ-попереджень (загрози)
/// 5. `muteClearSound` — вимкнення звуку для відбою тривоги
/// 6. `vibrationEnabled` — вібрація при будь-яких подіях
///
/// **Регіони:**
/// - `allRegionsTracked` — відстежувати всі регіони України
/// - `trackedRegionsString` — список обраних регіонів (розділені ";")
///
/// **App Group:**
/// Налаштування зберігаються в `UserDefaults(suiteName: "group.com.sirenua.shared")`,
/// щоб вони були доступні NotificationServiceExtension, який iOS запускає
/// навіть коли додаток вбитий з пам'яті. При першому запуску існуючі значення
/// мігрують з `UserDefaults.standard` до shared suite.
///
/// Thread-safe nonisolated getters доступні з будь-якого потоку через shared `UserDefaults`.
final class NotificationSettings: ObservableObject, @unchecked Sendable {
    static let shared = NotificationSettings()

    /// App Group suite name — спільне сховище між основним додатком та NSE
    static let suiteName = "group.com.sirenua.shared"

    /// Shared UserDefaults, доступні і основному додатку, і NotificationServiceExtension
    private static let sharedDefaults: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            settingsLogger.error("Failed to create shared UserDefaults with suiteName: \(suiteName). Falling back to .standard")
            return .standard
        }
        return defaults
    }()

    // MARK: Keys
    enum Keys {
        static let notificationsEnabled = "notificationsEnabled"
        static let criticalAlertsEnabled = "criticalAlertsEnabled"
        static let muteAlarmsSound = "muteAlarmsSound"
        static let muteThreatsSound = "muteThreatsSound"
        static let muteClearSound = "muteClearSound"
        static let muteThreatClearSound = "muteThreatClearSound"
        static let vibrationEnabled = "vibrationEnabled"
        static let allRegionsTracked = "allRegionsTracked"
        static let trackedRegionsString = "trackedRegionsString"
        static let allUkraineTrajectoriesEnabled = "allUkraineTrajectoriesEnabled"
        static let isPremium = "premiumEnabled"
        /// Migration flag — чи вже мігрували з standard до shared
        static let didMigrateToAppGroup = "didMigrateToAppGroup_v1"
    }

    // MARK: Published Properties
    @Published var notificationsEnabled: Bool {
        didSet {
            Self.sharedDefaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
            settingsLogger.info("notificationsEnabled changed: \(self.notificationsEnabled)")
            NotificationManager.shared.syncTopicSubscriptions()
        }
    }

    @Published var criticalAlertsEnabled: Bool {
        didSet {
            Self.sharedDefaults.set(criticalAlertsEnabled, forKey: Keys.criticalAlertsEnabled)
            settingsLogger.info("criticalAlertsEnabled changed: \(self.criticalAlertsEnabled)")
        }
    }

    @Published var muteAlarmsSound: Bool {
        didSet {
            Self.sharedDefaults.set(muteAlarmsSound, forKey: Keys.muteAlarmsSound)
            settingsLogger.info("muteAlarmsSound changed: \(self.muteAlarmsSound)")
        }
    }

    @Published var muteThreatsSound: Bool {
        didSet {
            Self.sharedDefaults.set(muteThreatsSound, forKey: Keys.muteThreatsSound)
            settingsLogger.info("muteThreatsSound changed: \(self.muteThreatsSound)")
        }
    }

    @Published var muteClearSound: Bool {
        didSet {
            Self.sharedDefaults.set(muteClearSound, forKey: Keys.muteClearSound)
            settingsLogger.info("muteClearSound changed: \(self.muteClearSound)")
        }
    }

    @Published var muteThreatClearSound: Bool {
        didSet {
            Self.sharedDefaults.set(muteThreatClearSound, forKey: Keys.muteThreatClearSound)
            settingsLogger.info("muteThreatClearSound changed: \(self.muteThreatClearSound)")
        }
    }

    @Published var vibrationEnabled: Bool {
        didSet {
            Self.sharedDefaults.set(vibrationEnabled, forKey: Keys.vibrationEnabled)
            settingsLogger.info("vibrationEnabled changed: \(self.vibrationEnabled)")
        }
    }

    @Published var allRegionsTracked: Bool {
        didSet {
            Self.sharedDefaults.set(allRegionsTracked, forKey: Keys.allRegionsTracked)
            NotificationManager.shared.syncTopicSubscriptions()
        }
    }

    @Published var trackedRegionsString: String {
        didSet {
            Self.sharedDefaults.set(trackedRegionsString, forKey: Keys.trackedRegionsString)
            NotificationManager.shared.syncTopicSubscriptions()
        }
    }

    @Published var allUkraineTrajectoriesEnabled: Bool {
        didSet {
            Self.sharedDefaults.set(allUkraineTrajectoriesEnabled, forKey: Keys.allUkraineTrajectoriesEnabled)
            settingsLogger.info("allUkraineTrajectoriesEnabled changed: \(self.allUkraineTrajectoriesEnabled)")
        }
    }

    @Published var isPremium: Bool {
        didSet {
            Self.sharedDefaults.set(isPremium, forKey: Keys.isPremium)
            settingsLogger.info("isPremium changed: \(self.isPremium)")
        }
    }

    // MARK: Init
    nonisolated private init() {
        let defaults = Self.sharedDefaults

        // Migration: перенести існуючі налаштування з standard → shared (одноразово)
        Self.migrateFromStandardIfNeeded()

        self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        self.criticalAlertsEnabled = defaults.object(forKey: Keys.criticalAlertsEnabled) as? Bool ?? true
        self.muteAlarmsSound = defaults.bool(forKey: Keys.muteAlarmsSound)
        self.muteThreatsSound = defaults.bool(forKey: Keys.muteThreatsSound)
        self.muteClearSound = defaults.bool(forKey: Keys.muteClearSound)
        self.muteThreatClearSound = defaults.bool(forKey: Keys.muteThreatClearSound)
        self.vibrationEnabled = defaults.object(forKey: Keys.vibrationEnabled) as? Bool ?? true
        self.allRegionsTracked = defaults.object(forKey: Keys.allRegionsTracked) as? Bool ?? true
        self.trackedRegionsString = defaults.string(forKey: Keys.trackedRegionsString) ?? ""
        self.allUkraineTrajectoriesEnabled = defaults.bool(forKey: Keys.allUkraineTrajectoriesEnabled)
        self.isPremium = defaults.bool(forKey: Keys.isPremium)
    }

    // MARK: Migration

    /// Одноразова міграція з `UserDefaults.standard` до App Group shared suite.
    /// Зберігає прапор `didMigrateToAppGroup_v1` щоб не повторювати.
    private static func migrateFromStandardIfNeeded() {
        let shared = sharedDefaults
        guard !shared.bool(forKey: Keys.didMigrateToAppGroup) else { return }

        let standard = UserDefaults.standard
        let keysToMigrate = [
            Keys.notificationsEnabled,
            Keys.criticalAlertsEnabled,
            Keys.muteAlarmsSound,
            Keys.muteThreatsSound,
            Keys.muteClearSound,
            Keys.muteThreatClearSound,
            Keys.vibrationEnabled,
            Keys.allRegionsTracked,
            Keys.trackedRegionsString,
            Keys.allUkraineTrajectoriesEnabled,
        ]

        var migratedCount = 0
        for key in keysToMigrate {
            if let value = standard.object(forKey: key) {
                shared.set(value, forKey: key)
                migratedCount += 1
            }
        }

        shared.set(true, forKey: Keys.didMigrateToAppGroup)
        settingsLogger.info("✅ Migrated \(migratedCount) settings from standard → App Group shared defaults")
    }

    // MARK: Nonisolated Thread-Safe Getters (Accessible from background threads / NotificationManager)

    nonisolated var isNotificationsEnabled: Bool {
        Self.sharedDefaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
    }

    nonisolated var isCriticalAlertsEnabled: Bool {
        Self.sharedDefaults.object(forKey: Keys.criticalAlertsEnabled) as? Bool ?? true
    }

    nonisolated var isMuteAlarmsSound: Bool {
        Self.sharedDefaults.bool(forKey: Keys.muteAlarmsSound)
    }

    nonisolated var isMuteThreatsSound: Bool {
        Self.sharedDefaults.bool(forKey: Keys.muteThreatsSound)
    }

    nonisolated var isMuteClearSound: Bool {
        Self.sharedDefaults.bool(forKey: Keys.muteClearSound)
    }

    nonisolated var isMuteThreatClearSound: Bool {
        Self.sharedDefaults.bool(forKey: Keys.muteThreatClearSound)
    }

    nonisolated var isVibrationEnabled: Bool {
        Self.sharedDefaults.object(forKey: Keys.vibrationEnabled) as? Bool ?? true
    }

    nonisolated var isAllUkraineTrajectoriesEnabled: Bool {
        Self.sharedDefaults.bool(forKey: Keys.allUkraineTrajectoriesEnabled)
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

    nonisolated var shouldPlayThreatClearSound: Bool {
        isNotificationsEnabled && !isMuteThreatClearSound
    }

    nonisolated var shouldVibrate: Bool {
        isNotificationsEnabled && isVibrationEnabled
    }

    nonisolated func isTracked(_ regionName: String) -> Bool {
        let allTracked = Self.sharedDefaults.object(forKey: Keys.allRegionsTracked) as? Bool ?? true
        guard !allTracked else { return true }
        let trackedString = Self.sharedDefaults.string(forKey: Keys.trackedRegionsString) ?? ""
        guard !trackedString.isEmpty else { return false }
        let trackedList = trackedString.components(separatedBy: ";").filter { !$0.isEmpty }
        return trackedList.contains(regionName)
    }

    func reloadFromUserDefaults() {
        let defaults = Self.sharedDefaults
        self.notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        self.criticalAlertsEnabled = defaults.object(forKey: Keys.criticalAlertsEnabled) as? Bool ?? true
        self.muteAlarmsSound = defaults.bool(forKey: Keys.muteAlarmsSound)
        self.muteThreatsSound = defaults.bool(forKey: Keys.muteThreatsSound)
        self.muteClearSound = defaults.bool(forKey: Keys.muteClearSound)
        self.muteThreatClearSound = defaults.bool(forKey: Keys.muteThreatClearSound)
        self.vibrationEnabled = defaults.object(forKey: Keys.vibrationEnabled) as? Bool ?? true
        self.allRegionsTracked = defaults.object(forKey: Keys.allRegionsTracked) as? Bool ?? true
        self.trackedRegionsString = defaults.string(forKey: Keys.trackedRegionsString) ?? ""
        self.allUkraineTrajectoriesEnabled = defaults.bool(forKey: Keys.allUkraineTrajectoriesEnabled)
        self.isPremium = defaults.bool(forKey: Keys.isPremium)
    }

    func setTracked(_ regionName: String, isOn: Bool) {
        var list: [String]
        if allRegionsTracked {
            list = RegionRegistry.allRegions
        } else {
            list = trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }
        }

        if isOn {
            if !list.contains(regionName) { list.append(regionName) }
        } else {
            list.removeAll { $0 == regionName }
        }

        trackedRegionsString = list.joined(separator: ";")
        if list.count == RegionRegistry.allRegions.count {
            allRegionsTracked = true
        } else {
            allRegionsTracked = false
        }
    }
}
