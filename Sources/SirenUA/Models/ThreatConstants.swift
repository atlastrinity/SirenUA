import SwiftUI

/// Єдині константи та реєстр об'єктів загрози (прильоту/вильоту) для всього клієнтського додатку.
/// Повністю синхронізовано із сервером (threat_types.py).
public enum ThreatConstants {
    // 1. Строкові ідентифікатори загроз (Single Source of Truth)
    public static let shahed = "shahed"
    public static let cruiseMissile = "cruise_missile"
    public static let ballistic = "ballistic"
    public static let mig31k = "mig31k"
    public static let kab = "kab"
    public static let tu95 = "tu95"
    public static let tu22m3 = "tu22m3"
    public static let su35 = "su35_su57"
    public static let su35Alt = "su35"
    public static let iskander = "iskander"
    public static let artillery = "artillery"
    public static let zircon = "zircon"
    public static let mlrs = "mlrs"
    public static let fpv = "fpv"
    public static let recon = "recon"
    public static let reconUav = "recon_uav"
    public static let officialAlarm = "official_alarm"
    public static let unknown = "unknown"

    // 2. Назви українською для активних загроз
    public static func title(for threatType: String?) -> String {
        guard let threatType = threatType?.lowercased() else { return "Повітряна тривога" }
        switch threatType {
        case shahed: return "БпЛА «Шахед»"
        case cruiseMissile: return "Крилаті ракети"
        case ballistic: return "Балістична ракета"
        case mig31k: return "МіГ-31К (Кинджал)"
        case kab: return "Керовані авіабомби (КАБ)"
        case tu95: return "Ту-95МС (крилаті ракети)"
        case tu22m3: return "Ту-22М3 (ракети Х-22/Х-32)"
        case su35, su35Alt: return "Тактична авіація (Су-34/Су-35)"
        case iskander: return "Іскандер-М"
        case artillery: return "Артилерійський обстріл"
        case zircon: return "Гіперзвукова ракета Циркон"
        case mlrs: return "РСЗВ (Торнадо-С / Град)"
        case fpv: return "FPV дрон / Ланцет"
        case recon, reconUav: return "Розвідувальний БпЛА"
        case officialAlarm: return "Повітряна тривога"
        default: return "Повітряна загроза"
        }
    }

    // 2b. Назви для відбою загроз
    public static func clearTitle(for threatType: String?, detail: String? = nil) -> String {
        let detailLower = detail?.lowercased() ?? ""
        let type = threatType?.lowercased()
        
        switch type {
        case shahed:
            return "Відбій загрози: БпЛА «Шахед»"
        case cruiseMissile:
            return "Відбій загрози: Крилаті ракети"
        case ballistic:
            return "Відбій загрози: Балістика"
        case mig31k:
            return "Відбій загрози: МіГ-31К"
        case kab:
            return "Відбій загрози: КАБ"
        case tu95:
            return "Відбій загрози: Ту-95МС"
        case tu22m3:
            return "Відбій загрози: Ту-22М3"
        case su35, su35Alt:
            return "Відбій загрози: Тактична авіація"
        case iskander:
            return "Відбій загрози: Іскандер"
        case artillery:
            return "Відбій загрози: Артилерія"
        case zircon:
            return "Відбій загрози: Циркон"
        case mlrs:
            return "Відбій загрози: РСЗВ"
        case fpv:
            return "Відбій загрози: FPV дрон"
        case recon, reconUav:
            return "Відбій загрози: Розвідувальний БпЛА"
        case officialAlarm:
            if !detailLower.isEmpty {
                if detailLower.contains("балістик") {
                    return "Відбій загрози: Балістика"
                } else if detailLower.contains("шахед") || detailLower.contains("бпла") || detailLower.contains("дрон") {
                    return "Відбій загрози: БпЛА «Шахед»"
                } else if detailLower.contains("ракет") || detailLower.contains("крилат") {
                    return "Відбій загрози: Крилаті ракети"
                } else if detailLower.contains("каб") || detailLower.contains("авіац") {
                    return "Відбій загрози: КАБ / Авіація"
                } else if detailLower.contains("міг") || detailLower.contains("кинджал") {
                    return "Відбій загрози: МіГ-31К"
                } else if detailLower.contains("загроз") {
                    return "Відбій загрози"
                }
            }
            return "Відбій повітряної тривоги"
        default:
            if !detailLower.isEmpty {
                if detailLower.contains("балістик") {
                    return "Відбій загрози: Балістика"
                } else if detailLower.contains("шахед") || detailLower.contains("бпла") || detailLower.contains("дрон") {
                    return "Відбій загрози: БпЛА «Шахед»"
                } else if detailLower.contains("ракет") {
                    return "Відбій загрози: Крилаті ракети"
                } else if detailLower.contains("каб") {
                    return "Відбій загрози: КАБ"
                } else if detailLower.contains("тривог") {
                    return "Відбій повітряної тривоги"
                }
            }
            return "Відбій загрози"
        }
    }

    // 3. Emoji іконки
    public static func emoji(for threatType: String?) -> String {
        guard let threatType = threatType?.lowercased() else { return "⚠️" }
        switch threatType {
        case shahed: return "🛩"
        case cruiseMissile: return "🚀"
        case ballistic, zircon: return "💥"
        case mig31k: return "✈️"
        case kab: return "💣"
        case tu95, tu22m3, su35, su35Alt: return "✈️"
        case iskander: return "🎯"
        case artillery, mlrs: return "💥"
        case fpv: return "🛸"
        case recon, reconUav: return "👁"
        case officialAlarm: return "🚨"
        default: return "⚠️"
        }
    }

    // 4. SF Symbol іконки
    public static func sfSymbol(for threatType: String?) -> String {
        guard let threatType = threatType?.lowercased() else { return "exclamationmark.triangle.fill" }
        switch threatType {
        case shahed: return "airplane"
        case cruiseMissile: return "bolt.fill"
        case ballistic, zircon: return "arrow.up.right"
        case mig31k: return "bolt.fill"
        case kab: return "flame.fill"
        case tu95: return "airplane"
        case tu22m3: return "airplane"
        case su35, su35Alt: return "airplane.departure"
        case iskander: return "scope"
        case artillery, mlrs: return "burst.fill"
        case fpv: return "viewfinder"
        case recon, reconUav: return "eye.fill"
        case officialAlarm: return "exclamationmark.triangle.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }

    // 5. Кольори загроз
    public static func color(for threatType: String?) -> Color {
        guard let threatType = threatType?.lowercased() else { return .orange }
        switch threatType {
        case shahed: return .yellow
        case cruiseMissile: return .red
        case ballistic, iskander, mig31k, zircon: return .purple
        case kab, mlrs: return .orange
        case tu95, tu22m3: return .red
        case su35, su35Alt: return .orange
        case artillery: return .orange
        case fpv: return .yellow
        case recon, reconUav: return .blue
        case officialAlarm: return .red
        default: return .orange
        }
    }

    // 6. Середні швидкості руху (км/год) для розрахунку дольоту
    public static func speedKmh(for threatType: String?) -> Double {
        guard let threatType = threatType?.lowercased() else { return 300.0 }
        switch threatType {
        case shahed: return 165.0
        case cruiseMissile: return 850.0
        case ballistic, iskander: return 5500.0
        case mig31k: return 2500.0
        case kab: return 350.0
        case tu95: return 800.0
        case tu22m3: return 4200.0
        case su35, su35Alt: return 950.0
        case zircon: return 11000.0
        case mlrs: return 2200.0
        case fpv: return 140.0
        case artillery: return 1200.0
        case recon, reconUav: return 120.0
        default: return 300.0
        }
    }

    // 7. Опис у родовому відмінку для повідомлень
    public static func genitiveDescription(for threatType: String?) -> String {
        guard let threatType = threatType?.lowercased() else { return "повітряної атаки" }
        switch threatType {
        case mig31k:         return "атаки аеробалістичними ракетами Кинджал"
        case shahed:         return "ударних безпілотників Шахед"
        case cruiseMissile: return "крилатих ракет"
        case kab:            return "ударів керованими авіабомбами (КАБ)"
        case ballistic:      return "балістичних ракет"
        case tu95:           return "ракетного удару стратегічної авіації (Ту-95МС)"
        case tu22m3:         return "ударів надзвуковими ракетами (Ту-22М3)"
        case su35, su35Alt:  return "активності тактичної авіації (Су-34/35)"
        case iskander:       return "ударів балістичними ракетами Іскандер-М"
        case zircon:         return "гіперзвукових ракет Циркон"
        case artillery:      return "артилерійського обстрілу"
        case mlrs:           return "обстрілу з реактивних систем залпового вогню (РСЗВ)"
        case fpv:            return "атаки FPV-дронів"
        case recon, reconUav: return "розвідувальних БпЛА"
        case officialAlarm:  return "повітряної тривоги"
        default:             return "повітряної атаки"
        }
    }

    // 8. Формування заголовка сповіщення про загрозу
    public static func notificationTitle(for threatType: String?, confidence: Int, region: String) -> String {
        let threatName: String
        switch threatType?.lowercased() {
        case ballistic:      threatName = "Балістична загроза"
        case shahed:         threatName = "Загроза БпЛА Shahed"
        case cruiseMissile:  threatName = "Загроза крилатих ракет"
        case kab:            threatName = "Загроза КАБ"
        case mig31k:         threatName = "Зліт МіГ-31К (Кинджал)"
        case tu95:           threatName = "Зліт Ту-95МС (крилаті ракети)"
        case tu22m3:         threatName = "Зліт Ту-22М3 (ракети Х-22/Х-32)"
        case su35, su35Alt:  threatName = "Активність Су-34/35 (КАБ/ракети)"
        case iskander:       threatName = "Загроза Іскандер-М"
        case artillery:      threatName = "Загроза артобстрілу"
        case zircon:         threatName = "Загроза ракети Циркон"
        case mlrs:           threatName = "Загроза обстрілу РСЗВ"
        case fpv:            threatName = "Загроза FPV-дронів"
        case recon, reconUav: threatName = "Виявлено розвідувальний БпЛА"
        case officialAlarm:  threatName = "Офіційна повітряна тривога"
        default:             threatName = "Повітряна загроза"
        }
        let indicator: String
        if confidence >= 85 {
            indicator = "🔴 Висока ймовірність"
        } else if confidence >= 60 {
            indicator = "🟠 Ймовірна загроза"
        } else {
            indicator = "🟡 Можлива загроза"
        }
        return "\(indicator): \(threatName) (\(region))"
    }
}
