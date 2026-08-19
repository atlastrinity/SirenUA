import UserNotifications
import OSLog

// MARK: - NotificationService

/// Notification Service Extension — iOS запускає цей процес при КОЖНОМУ push
/// з `mutable-content: 1`, навіть коли основний додаток вбитий з пам'яті.
///
/// Extension читає 6 тогглів налаштувань з App Group UserDefaults
/// і модифікує push перед показом: додає або прибирає звук та interruptionLevel.
///
/// Тогли:
/// 1. `notificationsEnabled` — головний вимикач
/// 2. `criticalAlertsEnabled` — пробивання DND (critical / timeSensitive)
/// 3. `muteAlarmsSound` — звук офіційних тривог
/// 4. `muteThreatsSound` — звук ШІ-загроз
/// 5. `muteClearSound` — звук відбою
/// 6. `vibrationEnabled` — (не впливає на push, лише in-app)
final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    /// Shared UserDefaults через App Group — єдине джерело налаштувань
    private let shared = UserDefaults(suiteName: "group.com.sirenua.shared")

    private let nseLogger = Logger(subsystem: "com.sirenua", category: "NSE")

    /// Throttle для дедуплікації звуків — узгоджений з NotificationManager (15с)
    private static let soundThrottle: TimeInterval = 15.0

    // MARK: - Entry Point

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler

        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        self.bestAttemptContent = content

        let data = content.userInfo

        // 1. Визначити тип події через canonical EventType enum
        let eventType = EventType.resolve(from: data, title: content.title)

        // 2. Перевірити головний вимикач
        let notifsEnabled = shared?.object(forKey: "notificationsEnabled") as? Bool ?? true
        guard notifsEnabled else {
            nseLogger.info("NSE: notifications disabled globally, delivering silent")
            content.sound = nil
            content.interruptionLevel = .passive
            contentHandler(content)
            return
        }

        // 2a. Перевірити чи відстежується регіон користувачем (так само як тоггли)
        var regionName: String? = data["region"] as? String ?? data["regionName"] as? String
        if regionName == nil, let aps = data["aps"] as? [String: Any],
           let custom = aps["custom_data"] as? [String: Any] {
            regionName = custom["region"] as? String
        }

        let allTracked = shared?.object(forKey: "allRegionsTracked") as? Bool ?? true
        if !allTracked, let region = regionName, !region.isEmpty {
            let trackedString = shared?.string(forKey: "trackedRegionsString") ?? ""
            let trackedList = trackedString.components(separatedBy: ";").filter { !$0.isEmpty }
            if !trackedList.contains(region) {
                nseLogger.info("NSE: region \(region) is not tracked by user, delivering silent")
                content.sound = nil
                content.interruptionLevel = .passive
                contentHandler(content)
                return
            }
        }

        // 3. Визначити чи грати звук на основі відповідного тогла
        let shouldPlaySound: Bool
        switch eventType {
        case .alarm:
            shouldPlaySound = !(shared?.bool(forKey: "muteAlarmsSound") ?? false)
        case .threat:
            shouldPlaySound = !(shared?.bool(forKey: "muteThreatsSound") ?? false)
        case .clear:
            shouldPlaySound = !(shared?.bool(forKey: "muteClearSound") ?? false)
        case .threatClear:
            shouldPlaySound = !(shared?.bool(forKey: "muteThreatClearSound") ?? false)
        }

        // 3a. Дедуплікація, пріоритетизація та вікно виголошення фрази (через NotificationSoundPolicy)
        let allowSoundPlayback = NotificationSoundPolicy.shouldAllowPlayback(
            for: eventType,
            regionName: regionName,
            shouldPlaySoundByUser: shouldPlaySound,
            sharedDefaults: shared
        )

        // 4. Vibration & Critical alerts toggles
        let criticalEnabled = shared?.object(forKey: "criticalAlertsEnabled") as? Bool ?? true
        let vibrationEnabled = shared?.object(forKey: "vibrationEnabled") as? Bool ?? true

        // 5. Встановити звук та interruption level
        if allowSoundPlayback {
            let soundFile = (data["sound_file"] as? String) ?? eventType.soundFile

            // Critical alert — ВИКЛЮЧНО для офіційної тривоги (.alarm) та офіційного відбою (.clear)
            let isCritical = criticalEnabled && (eventType == .alarm || eventType == .clear)

            if isCritical {
                // Critical alert: пробиває DND + Silent Mode (для офіційних сигналів)
                content.sound = UNNotificationSound.criticalSoundNamed(
                    UNNotificationSoundName(soundFile), withAudioVolume: 1.0)
                content.interruptionLevel = .critical
                nseLogger.info("NSE: \(eventType.rawValue) → critical sound: \(soundFile)")
            } else {
                // TimeSensitive / Regular: для локальних ШІ-загроз (.threat) та відбоїв загроз (.threatClear)
                content.sound = UNNotificationSound(named: UNNotificationSoundName(soundFile))
                content.interruptionLevel = .timeSensitive
                nseLogger.info("NSE: \(eventType.rawValue) → standard timeSensitive sound: \(soundFile)")
            }
        } else if vibrationEnabled {
            // Звук вимкнений користувачем або задедуплікований, але вібрація увімкнена →
            // використовуємо silence.wav (тихий файл) замість .default, щоб отримати
            // вібрацію без дефолтного iOS звуку коли телефон не на беззвучному
            content.sound = UNNotificationSound(named: UNNotificationSoundName("silence.wav"))
            content.interruptionLevel = .timeSensitive
            nseLogger.info("NSE: \(eventType.rawValue) → sound muted/deduplicated, vibration via silence.wav")
        } else {
            // Звук та вібрація вимкнені повністю
            content.sound = nil
            content.interruptionLevel = .passive
            nseLogger.info("NSE: \(eventType.rawValue) → sound and vibration disabled")
        }

        contentHandler(content)
    }

    override func serviceExtensionTimeWillExpire() {
        // Якщо iOS не встигла — відправляємо що є (краще показати щось, ніж нічого)
        nseLogger.warning("NSE: time expired, delivering best attempt content")
        if let content = bestAttemptContent, let handler = contentHandler {
            handler(content)
        }
    }
}
