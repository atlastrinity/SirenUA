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
    public static let urbanFights = "urban_fights"
    public static let chemical = "chemical"
    public static let nuclear = "nuclear"
    public static let zircon = "zircon"
    public static let mlrs = "mlrs"
    public static let fpv = "fpv"
    public static let recon = "recon"
    public static let reconUav = "recon_uav"
    public static let reconUAV = "recon_uav"
    public static let officialAlarm = "official_alarm"
    public static let unknown = "unknown"

    public static let all: [String] = [
        shahed,
        cruiseMissile,
        ballistic,
        mig31k,
        kab,
        tu95,
        tu22m3,
        su35,
        iskander,
        artillery,
        urbanFights,
        chemical,
        nuclear,
        zircon,
        mlrs,
        fpv,
        recon,
        reconUav,
        officialAlarm,
        unknown
    ]

    // 2. Назви українською для активних загроз (Display Titles)
    public static func title(for threatType: String?) -> String {
        guard let threatType = threatType?.lowercased() else { return "Повітряна тривога" }
        switch threatType {
        case shahed, "shahed_136", "shahed_131", "geran", "drone", "uav", "kamikaze_drone":
            return "БПЛА Shahed-136"
        case "reactive_uav", "jet_shahed", "jet_drone":
            return "Реактивний ударний БпЛА"
        case cruiseMissile, "kalibr", "kh101", "kh_101", "kh555", "kh_555", "kh59", "kh_59", "kh69", "kh_69":
            return "Крилаті ракети"
        case ballistic, "iskander_m", "kn23", "s300", "s400", "ballistic_missile":
            return "Балістична ракета"
        case mig31k, "kinzhal", "kh47m2":
            return "МіГ-31К (Кинджал)"
        case kab, "uab", "fab", "umpb", "odab", "rbk", "guided_bomb", "glide_bomb", "grom_e1":
            return "Керовані авіабомби (КАБ)"
        case tu95, "tu95ms":
            return "Ту-95МС (крилаті ракети)"
        case tu22m3, "kh22", "kh_22", "kh32", "kh_32":
            return "Ту-22М3 (ракети Х-22/Х-32)"
        case su35, su35Alt, "su34", "su57", "su30", "tactical_aviation", "tactical aviation":
            return "Су-35/Су-57 (тактична авіація)"
        case iskander, "iskander_k":
            return "Іскандер-М"
        case artillery:
            return "Артилерія"
        case urbanFights:
            return "Вуличні бої"
        case chemical:
            return "Хімічна загроза"
        case nuclear:
            return "Радіаційна небезпека"
        case zircon:
            return "Гіперзвукова ракета 3M22 Циркон"
        case mlrs, "tornado_s", "grad", "uragan", "smerch":
            return "РСЗВ (Торнадо-С / Град / Ураган)"
        case fpv, "lancet":
            return "FPV дрон / Ланцет"
        case recon, reconUav, "orlan", "zala", "supercam", "recon_drone":
            return "Розвідувальний БПЛА"
        case officialAlarm:
            return "Повітряна тривога"
        default:
            return "Повітряна загроза"
        }
    }

    // 2a. Короткі назви загроз (Short Names)
    public static func shortName(for threatType: String?) -> String {
        guard let threatType = threatType?.lowercased() else { return "" }
        switch threatType {
        case shahed, "shahed_136", "shahed_131", "geran", "drone", "uav", "kamikaze_drone":
            return "БпЛА"
        case "reactive_uav", "jet_shahed", "jet_drone":
            return "реактивний БпЛА"
        case cruiseMissile, "kalibr", "kh101", "kh_101", "kh555", "kh_555", "kh59", "kh_59", "kh69", "kh_69":
            return "крилата ракета"
        case ballistic, "iskander_m", "kn23", "s300", "s400", "ballistic_missile":
            return "балістика"
        case mig31k, "kinzhal", "kh47m2":
            return "МіГ-31К"
        case kab, "uab", "fab", "umpb", "odab", "rbk", "guided_bomb", "glide_bomb", "grom_e1":
            return "КАБ"
        case tu95, "tu95ms":
            return "Ту-95МС"
        case tu22m3, "kh22", "kh_22", "kh32", "kh_32":
            return "Ту-22М3"
        case su35, su35Alt, "su34", "su57", "su30", "tactical_aviation", "tactical aviation":
            return "Су-35"
        case iskander, "iskander_k":
            return "Іскандер-М"
        case artillery:
            return "обстріл"
        case urbanFights:
            return "вуличні бої"
        case chemical:
            return "хімнебезпека"
        case nuclear:
            return "радіація"
        case zircon:
            return "Циркон"
        case mlrs, "tornado_s", "grad", "uragan", "smerch":
            return "РСЗВ"
        case fpv, "lancet":
            return "FPV-дрон"
        case recon, reconUav, "orlan", "zala", "supercam", "recon_drone":
            return "розвідник"
        case officialAlarm:
            return "тривога"
        default:
            return "загроза"
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
        case urbanFights:
            return "Відбій загрози: Вуличні бої"
        case chemical:
            return "Відбій загрози: Хімічна небезпека"
        case nuclear:
            return "Відбій загрози: Радіаційна небезпека"
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
        case urbanFights: return "🛡"
        case chemical: return "🧪"
        case nuclear: return "☢️"
        case fpv: return "🛸"
        case recon, reconUav: return "👁"
        case officialAlarm: return "🚨"
        default: return "⚠️"
        }
    }

    // 4. SF Symbol іконки (SFSymbol Constants)
    public static func sfSymbol(for threatType: String?) -> String {
        guard let threatType = threatType?.lowercased() else { return "exclamationmark.triangle.fill" }
        switch threatType {
        case shahed: return "airplane.circle.fill"
        case cruiseMissile: return "paperplane.fill"
        case ballistic: return "flame.fill"
        case mig31k: return "bolt.fill"
        case kab: return "circle.circle.fill"
        case tu95: return "airplane"
        case tu22m3: return "airplane"
        case su35, su35Alt: return "airplane.departure"
        case iskander: return "flame.fill"
        case artillery: return "burst.fill"
        case urbanFights: return "shield.slash.fill"
        case chemical: return "smoke.fill"
        case nuclear: return "atom"
        case zircon: return "bolt.horizontal.fill"
        case mlrs: return "sparkles"
        case fpv: return "viewfinder"
        case recon, reconUav: return "eye.fill"
        case officialAlarm: return "bell.fill"
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
        case urbanFights: return .red
        case chemical: return .yellow
        case nuclear: return .purple
        case fpv: return .yellow
        case recon, reconUav: return .blue
        case officialAlarm: return .red
        default: return .orange
        }
    }

    // 6. Середні швидкості руху (км/год) для розрахунку дольоту (Kinematics)
    public static func speedKmh(for threatType: String?) -> Double {
        guard let threatType = threatType?.lowercased() else { return 300.0 }
        switch threatType {
        case shahed: return 165.0
        case cruiseMissile: return 850.0
        case ballistic, iskander: return 5500.0
        case mig31k: return 2500.0
        case kab: return 900.0
        case tu95: return 800.0
        case tu22m3: return 4200.0
        case su35, su35Alt: return 950.0
        case zircon: return 11000.0
        case mlrs: return 2200.0
        case fpv: return 140.0
        case artillery: return 1200.0
        case urbanFights: return 0.0
        case chemical: return 50.0
        case nuclear: return 0.0
        case recon, reconUav: return 120.0
        case officialAlarm: return 0.0
        default: return 300.0
        }
    }

    // 6b. Таймаути автозняття (TTL Seconds)
    public static func defaultDelay(for threatType: String?, isRegex: Bool = false) -> Int {
        guard let threatType = threatType?.lowercased() else { return 3600 }
        switch threatType {
        case shahed: return 10800
        case cruiseMissile: return isRegex ? 3600 : 2700
        case ballistic: return isRegex ? 1800 : 600
        case mig31k: return isRegex ? 2700 : 1800
        case kab: return isRegex ? 420 : 300
        case tu95: return 5400
        case tu22m3: return 3600
        case su35, su35Alt: return isRegex ? 3600 : 2700
        case iskander: return isRegex ? 1800 : 1200
        case artillery: return 1800
        case urbanFights: return 3600
        case chemical: return 3600
        case nuclear: return 7200
        case zircon: return isRegex ? 1200 : 600
        case mlrs: return isRegex ? 1800 : 1200
        case fpv: return 1800
        case recon, reconUav: return 3600
        case officialAlarm: return 3600
        default: return 3600
        }
    }

    // 6c. Дефолтні рядки очікуваного часу дольоту (Default ETAs)
    public static func defaultEta(for threatType: String?, isRegex: Bool = false) -> String {
        guard let threatType = threatType?.lowercased() else { return "до 30 хв" }
        switch threatType {
        case shahed: return isRegex ? "до 1.5 год" : "до 3 год"
        case cruiseMissile: return isRegex ? "до 30 хв" : "до 55 хв"
        case ballistic: return isRegex ? "до 5 хв" : "до 15 хв"
        case mig31k: return isRegex ? "до 40 хв" : "до 40 хв"
        case kab: return isRegex ? "до 5 хв" : "до 5 хв"
        case tu95: return isRegex ? "до 1.5 год" : "до 2 год"
        case tu22m3: return isRegex ? "до 10 хв" : "до 15 хв"
        case su35, su35Alt: return isRegex ? "до 15 хв" : "до 20 хв"
        case iskander: return isRegex ? "до 5 хв" : "до 25 хв"
        case artillery: return isRegex ? "до 5 хв" : "до 10 хв"
        case urbanFights: return "в зоні"
        case chemical: return isRegex ? "до 15 хв" : "до 30 хв"
        case nuclear: return "в зоні"
        case zircon: return isRegex ? "до 3 хв" : "до 5 хв"
        case mlrs: return isRegex ? "до 5 хв" : "до 10 хв"
        case fpv: return isRegex ? "до 15 хв" : "до 20 хв"
        case recon, reconUav: return isRegex ? "до 30 хв" : "до 30 хв"
        case officialAlarm: return "-"
        default: return "до 30 хв"
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
        case urbanFights:   return "вуличних боїв"
        case chemical:       return "хімічної загрози"
        case nuclear:        return "радіаційної небезпеки"
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
        case urbanFights:   threatName = "Загроза вуличних боїв"
        case chemical:       threatName = "Хімічна небезпека"
        case nuclear:        threatName = "Радіаційна небезпека"
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

    // 9. База тактичних аеродромів та носіїв (Зліт)
    public static func carrierOrigin(for threatType: String?, detail: String? = nil) -> String? {
        let det = detail?.lowercased() ?? ""
        if det.contains("саваслейк") { return "Аеродром Саваслейка (Нижньогородська обл. РФ)" }
        if det.contains("олень") { return "Аеродром Оленья (Мурманська обл. РФ)" }
        if det.contains("енгельс") { return "Аеродром Енгельс-2 (Саратовська обл. РФ)" }
        if det.contains("шайковк") { return "Аеродром Шайковка (Калузька обл. РФ)" }
        if det.contains("моздок") { return "Аеродром Моздок (Північна Осетія РФ)" }
        if det.contains("міллерово") { return "Аеродром Міллерово (Ростовська обл. РФ)" }
        if det.contains("балтимор") || det.contains("воронеж") { return "Аеродром Балтимор (Воронеж РФ)" }
        if det.contains("халіно") || det.contains("курськ") { return "Аеродром Халіно (Курськ РФ)" }
        if det.contains("єйськ") || det.contains("ейск") { return "Аеродром Єйськ (Краснодарський край РФ)" }
        if det.contains("приморсько") || det.contains("ахтарськ") { return "Приморсько-Ахтарськ (Краснодарський край РФ)" }
        if det.contains("чауд") { return "Мис Чауда (ТОТ Крим)" }
        if det.contains("севастопол") || det.contains("бельбек") { return "Аеродром Бельбек / Севастополь (ТОТ Крим)" }

        guard let type = threatType?.lowercased() else { return nil }
        switch type {
        case mig31k, "kinzhal", "kh47m2":
            return "Аеродром Саваслейка (Нижньогородська обл. РФ)"
        case tu95, "tu95ms":
            return "Аеродром Оленья / Енгельс-2"
        case tu22m3, "kh22", "kh32":
            return "Аеродром Шайковка / Моздок"
        case su35, su35Alt, "su34", "su57", "tactical_aviation", "tactical aviation":
            return "Аеродроми базування тактичної авіації РФ"
        case kab, "uab", "fab", "umpb", "odab", "rbk":
            return "Су-34/Су-35 (Тактична авіація РФ)"
        case shahed, "shahed_136", "reactive_uav":
            return "Пускові райони БпЛА (Чауда / Приморсько-Ахтарськ / Курськ)"
        default:
            return nil
        }
    }

    // 10. База рубежів пуску та секторів (Рубіж)
    public static func launchSector(for threatType: String?, detail: String? = nil, region: String? = nil) -> String? {
        let det = detail?.lowercased() ?? ""
        if det.contains("курськ") { return "Курська область (РФ)" }
        if det.contains("бєлгород") || det.contains("белгород") { return "Бєлгородська область (РФ)" }
        if det.contains("брянськ") || det.contains("брянск") { return "Брянська область (РФ)" }
        if det.contains("чорн") || det.contains("мор") { return "Акваторія Чорного моря" }
        if det.contains("азов") { return "Акваторія Азовського моря" }
        if det.contains("каспій") { return "Район пусків Каспійське море" }
        if det.contains("чауд") { return "Мис Чауда (ТОТ Крим)" }
        if det.contains("тарханкут") { return "Мис Тарханкут (ТОТ Крим)" }
        if det.contains("донбас") || det.contains("донецьк") { return "ТОТ Донецької області" }
        if det.contains("запоріж") { return "ТОТ Запорізької області" }
        if det.contains("херсон") { return "ТОТ Херсонської області" }

        guard let type = threatType?.lowercased() else { return nil }
        switch type {
        case kab, "uab", "fab", "umpb", "odab", "rbk":
            return "Рубежі пусків вздовж держкордону та лінії фронту"
        case mig31k, "kinzhal":
            return "Повітряний простір Рязанської / Тульської обл. РФ"
        case tu95, "tu95ms":
            return "Каспійське море / Енгельс (пусковий рубіж)"
        case tu22m3:
            return "Акваторія Чорного моря / Курська обл. РФ"
        case ballistic, "iskander", "iskander_m":
            return "Пускові райони ОТРК (Бєлгород / Крим / Ростов)"
        default:
            return nil
        }
    }
}
