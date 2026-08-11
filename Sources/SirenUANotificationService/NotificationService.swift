import UserNotifications
import OSLog

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

        // 1. Визначити тип події
        let eventType = (data["event_type"] as? String) ?? inferEventType(from: data, title: content.title)

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
        case "alarm":
            shouldPlaySound = !(shared?.bool(forKey: "muteAlarmsSound") ?? false)
        case "threat":
            shouldPlaySound = !(shared?.bool(forKey: "muteThreatsSound") ?? false)
        case "clear":
            shouldPlaySound = !(shared?.bool(forKey: "muteClearSound") ?? false)
        default:
            shouldPlaySound = !(shared?.bool(forKey: "muteAlarmsSound") ?? false)
        }

        // 4. Critical alerts toggle → interruption level
        let criticalEnabled = shared?.object(forKey: "criticalAlertsEnabled") as? Bool ?? true

        // 5. Встановити звук та interruption level
        if shouldPlaySound {
            let soundFile = (data["sound_file"] as? String) ?? defaultSoundFile(for: eventType)

            if criticalEnabled {
                // Critical alert: пробиває DND + Silent Mode (у користувача є схвалений entitlement від Apple)
                content.sound = UNNotificationSound.criticalSoundNamed(
                    UNNotificationSoundName(soundFile), withAudioVolume: 1.0)
                content.interruptionLevel = .critical
                nseLogger.info("NSE: \(eventType) → critical sound: \(soundFile)")
            } else {
                // TimeSensitive: пробиває Focus, але не Silent Mode
                content.sound = UNNotificationSound(named: UNNotificationSoundName(soundFile))
                content.interruptionLevel = .timeSensitive
                nseLogger.info("NSE: \(eventType) → timeSensitive sound: \(soundFile)")
            }
        } else {
            // Звук вимкнений користувачем для цього типу подій
            content.sound = nil
            content.interruptionLevel = .active
            nseLogger.info("NSE: \(eventType) → sound muted by user toggle")
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

    // MARK: - Helpers

    /// Звуковий файл за замовчуванням для кожного типу події
    private func defaultSoundFile(for eventType: String) -> String {
        switch eventType {
        case "alarm":  return "siren.wav"
        case "threat": return "warning.wav"
        case "clear":  return "vidbiy.wav"
        default:       return "siren.wav"
        }
    }

    /// Fallback визначення типу події, якщо сервер не надіслав `event_type`
    /// (для сумісності зі старими версіями серверу)
    private func inferEventType(from data: [AnyHashable: Any], title: String) -> String {
        // З data payload
        if let isOfficial = data["is_official"] as? String, isOfficial == "true" {
            return "alarm"
        }
        if let level = data["threat_level"] as? String, level == "none" {
            return "clear"
        }
        if let level = data["level"] as? String, level == "none" {
            return "clear"
        }

        // З title (emoji-based)
        let t = title.lowercased()
        if t.contains("🟢") || t.contains("відбій") { return "clear" }
        if t.contains("⚠️") || t.contains("загроза") { return "threat" }
        if t.contains("🚨") || t.contains("🔴") || t.contains("тривога") { return "alarm" }

        return "alarm"  // Default: treat unknown as alarm (safer)
    }
}
