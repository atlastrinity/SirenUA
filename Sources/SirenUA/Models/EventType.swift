import Foundation

// MARK: - EventType

/// Єдине джерело правди для типів подій та їх звуків.
///
/// Три типи подій у SirenUA:
/// - `alarm`  — офіційна тривога (сирена)
/// - `threat` — ШІ-загроза (КАБ, ракета, БпЛА)
/// - `clear`  — відбій тривоги
///
/// **Canonical definition** — дзеркальна копія існує в NSE
/// (`SirenUANotificationService/NotificationService.swift`).
/// При змінах — синхронізувати обидва місця.
enum EventType: String {
    case alarm   // Офіційна тривога
    case threat  // ШІ-загроза
    case clear   // Відбій тривоги

    /// Звуковий файл за замовчуванням для цього типу події.
    /// Загрози ЗАВЖДИ грають `warning.wav`, навіть при high confidence.
    var soundFile: String {
        switch self {
        case .alarm:  return "siren.wav"
        case .threat: return "warning.wav"
        case .clear:  return "vidbiy.wav"
        }
    }

    /// Визначити тип події з data payload push-нотифікації.
    /// Спочатку перевіряє explicit `event_type`, потім fallback-інференція
    /// з полів `is_official`, `threat_level`/`level`, та title emoji.
    static func resolve(from data: [AnyHashable: Any], title: String) -> EventType {
        // 1. Explicit event_type від сервера
        if let raw = data["event_type"] as? String, let type = EventType(rawValue: raw) {
            return type
        }

        // 2. Fallback: інференція з data полів
        if let isOfficial = data["is_official"] as? String, isOfficial == "true" {
            return .alarm
        }
        if let level = data["threat_level"] as? String, level == "none" {
            return .clear
        }
        if let level = data["level"] as? String, level == "none" {
            return .clear
        }

        // 3. Fallback: інференція з title (emoji-based)
        let t = title.lowercased()
        if t.contains("🟢") || t.contains("відбій") { return .clear }
        if t.contains("⚠️") || t.contains("загроза") { return .threat }
        if t.contains("🚨") || t.contains("🔴") || t.contains("тривога") { return .alarm }

        // Default: невідомий тип → alarm (безпечніше)
        return .alarm
    }
}
