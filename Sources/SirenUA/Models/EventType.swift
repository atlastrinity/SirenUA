import Foundation

// MARK: - EventType

/// Єдине джерело правди для типів подій та їх звуків.
///
/// Чотири типи подій у SirenUA:
/// - `alarm`       — офіційна тривога (сирена siren.wav)
/// - `threat`      — ШІ-загроза (КАБ, ракета, БпЛА warning.wav)
/// - `clear`       — відбій офіційної тривоги (vidbiy.wav)
/// - `threatClear` — відбій ШІ-загрози (clearance.wav)
///
/// **Shared definition** — включено як спільний файл джерел у проекті `project.yml`
/// для обох таргетів (`SirenUA` та `SirenUANotificationService`).
enum EventType: String {
    case alarm        // Офіційна тривога
    case threat       // ШІ-загроза
    case clear        // Відбій офіційної тривоги
    case threatClear  // Відбій ШІ-загрози

    /// Звуковий файл за замовчуванням для цього типу події.
    var soundFile: String {
        switch self {
        case .alarm:       return "siren.wav"
        case .threat:      return "warning.wav"
        case .clear:       return "vidbiy.wav"
        case .threatClear: return "clearance.wav"
        }
    }

    /// Визначити тип події з data payload push-нотифікації.
    /// Спочатку перевіряє explicit `event_type`, потім fallback-інференцію
    /// з полів `is_official`, `threat_level`/`level`, та title emoji.
    static func resolve(from data: [AnyHashable: Any], title: String) -> EventType {
        // 1. Explicit event_type від сервера
        if let raw = data["event_type"] as? String {
            if raw == "threat_clear" || raw == "clearance" {
                return .threatClear
            }
            if let type = EventType(rawValue: raw) {
                return type
            }
        }

        // 2. Fallback: інференція з data полів
        let isOfficialStr = data["is_official"] as? String ?? ""
        let isOfficial = isOfficialStr == "true" || (data["is_official"] as? Bool ?? false)
        let isClearLevel = (data["threat_level"] as? String == "none") || (data["level"] as? String == "none")

        if isClearLevel {
            return isOfficial ? .clear : .threatClear
        }

        if isOfficial {
            return .alarm
        }

        // 3. Fallback: інференція з title (emoji-based)
        let t = title.lowercased()
        if t.contains("відбій загрози") { return .threatClear }
        if t.contains("🟢") || t.contains("відбій") { return .clear }
        if t.contains("⚠️") || t.contains("загроза") { return .threat }
        if t.contains("🚨") || t.contains("🔴") || t.contains("тривога") { return .alarm }

        // Default: невідомий тип → alarm (безпечніше)
        return .alarm
    }
}
