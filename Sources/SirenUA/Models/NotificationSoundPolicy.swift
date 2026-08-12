import Foundation
import OSLog

private let soundPolicyLogger = Logger(subsystem: "com.sirenua", category: "SoundPolicy")

// MARK: - NotificationSoundPolicy

/// Єдине джерело правди для дедуплікації, пріоритетів та вікон виголошення звукових сповіщень.
///
/// **Спільний файл (Shared source):** включений до `project.yml` для обох таргетів:
/// `SirenUA` (головний додаток) та `SirenUANotificationService` (NSE розширення).
enum NotificationSoundPolicy {

    /// Повна тривалість звукового дедуплікатора (15 секунд)
    static let soundThrottle: TimeInterval = 15.0

    /// Мінімальне вікно виголошення фрази голосом (3.5 секунд).
    /// Запобігає обриву фрази на півслові при частій зміні загроз.
    static let minVoiceDuration: TimeInterval = 3.5

    /// Пріоритет загрози протягом якого відбій іншої області пригнічується (5.0 секунд)
    static let threatPriorityWindow: TimeInterval = 5.0

    /// Перевірити чи дозволено відтворення звуку для даної події та регіону.
    ///
    /// - Parameters:
    ///   - eventType: Тип події (`.alarm`, `.threat`, `.clear`, `.threatClear`)
    ///   - regionName: Назва регіону
    ///   - shouldPlaySoundByUser: Прапор дозволу звуку за налаштуваннями користувача
    ///   - sharedDefaults: `UserDefaults` App Group suite (`group.com.sirenua.shared`)
    ///   - now: Поточний час (`Date()`)
    /// - Returns: `true` якщо звук дозволено відтворити, `false` якщо його слід пригнітити
    static func shouldAllowPlayback(
        for eventType: EventType,
        regionName: String?,
        shouldPlaySoundByUser: Bool,
        sharedDefaults: UserDefaults?,
        now: Date = Date()
    ) -> Bool {
        guard shouldPlaySoundByUser else {
            soundPolicyLogger.info("Sound policy: Suppressed by user toggle for \(eventType.rawValue)")
            return false
        }

        let currentTimestamp = now.timeIntervalSince1970
        let lastSoundType = sharedDefaults?.string(forKey: "lastSoundEventType") ?? ""
        let lastSoundRegion = sharedDefaults?.string(forKey: "lastSoundRegion") ?? ""
        let lastSoundTime = sharedDefaults?.double(forKey: "lastSoundTimestamp") ?? 0.0
        let timeSinceLastSound = currentTimestamp - lastSoundTime

        // Якщо пройшло більше 15 секунд — дозволяємо будь-який звук
        guard timeSinceLastSound < soundThrottle else {
            recordPlayback(eventType: eventType, regionName: regionName, timestamp: currentTimestamp, sharedDefaults: sharedDefaults)
            return true
        }

        let currentRegion = regionName ?? ""
        let isSameRegion = (!currentRegion.isEmpty && currentRegion == lastSoundRegion)

        // 1. Мінімальне вікно 3.5с: якщо попередня фраза ще озвучується, не обриваємо її на півслові!
        if timeSinceLastSound < minVoiceDuration {
            soundPolicyLogger.info("Sound policy: Suppressed (previous voice line still playing: \(timeSinceLastSound)s < \(minVoiceDuration)s)")
            return false
        }

        // 2. ВІДБІЙ ДЛЯ ТІЄЇ Ж ОБЛАСТІ -> Дозволяємо відбій після закінчення 3.5с фрази!
        if (eventType == .clear || eventType == .threatClear) && isSameRegion {
            soundPolicyLogger.info("Sound policy: Clearance for SAME region (\(currentRegion)) -> Allowed for \(eventType.rawValue)")
            recordPlayback(eventType: eventType, regionName: regionName, timestamp: currentTimestamp, sharedDefaults: sharedDefaults)
            return true
        }

        // 3. Дублікат того ж типу для іншої області
        if eventType.rawValue == lastSoundType {
            soundPolicyLogger.info("Sound policy: Suppressed duplicate \(eventType.rawValue) sound for another region (\(currentRegion))")
            return false
        }

        // 4. Сирена офіційної тривоги не перебивається загрозою чи відбоєм чужої області
        if lastSoundType == "alarm" && (eventType == .threat || eventType == .clear || eventType == .threatClear) {
            soundPolicyLogger.info("Sound policy: Suppressed \(eventType.rawValue) sound for \(currentRegion) while alarm is active for \(lastSoundRegion)")
            return false
        }

        // 5. Загроза має вищий пріоритет за відбій іншої області протягом 5 секунд
        if lastSoundType == "threat" && (eventType == .clear || eventType == .threatClear) && timeSinceLastSound < threatPriorityWindow {
            soundPolicyLogger.info("Sound policy: Suppressed clear sound for \(currentRegion) while threat is active")
            return false
        }

        // Якщо пройшли всі перевірки — дозволяємо відтворення
        recordPlayback(eventType: eventType, regionName: regionName, timestamp: currentTimestamp, sharedDefaults: sharedDefaults)
        return true
    }

    /// Записати факт відтворення звуку в App Group `UserDefaults`
    static func recordPlayback(
        eventType: EventType,
        regionName: String?,
        timestamp: TimeInterval,
        sharedDefaults: UserDefaults?
    ) {
        sharedDefaults?.set(eventType.rawValue, forKey: "lastSoundEventType")
        sharedDefaults?.set(regionName ?? "", forKey: "lastSoundRegion")
        sharedDefaults?.set(timestamp, forKey: "lastSoundTimestamp")
    }
}
