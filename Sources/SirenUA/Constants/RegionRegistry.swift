import Foundation

/// Єдиний реєстр регіонів України для всього додатку SirenUA.
///
/// Містить:
/// - Канонічний список усіх 25 областей/міст
/// - Firebase topic mapping (регіон → FCM topic)
/// - Постійно активні (окуповані) території
///
/// Використовується у `NotificationSettings`, `NotificationManager`,
/// `SettingsView`, `ContentView`, `RegionOnboardingView`, `RegionSelectionSheet` тощо.
public enum RegionRegistry {

    // MARK: - Канонічний список регіонів

    /// Повний упорядкований список усіх 25 областей та міст України.
    /// Використовується для UI-переліків, вибору регіонів і FCM-підписок.
    public static let allRegions: [String] = [
        "Вінницька область",
        "Волинська область",
        "Дніпропетровська область",
        "Донецька область",
        "Житомирська область",
        "Закарпатська область",
        "Запорізька область",
        "Івано-Франківська область",
        "Київська область",
        "м. Київ",
        "Кіровоградська область",
        "Луганська область",
        "Львівська область",
        "Миколаївська область",
        "Одеська область",
        "Полтавська область",
        "Рівненська область",
        "Сумська область",
        "Тернопільська область",
        "Харківська область",
        "Херсонська область",
        "Хмельницька область",
        "Черкаська область",
        "Чернівецька область",
        "Чернігівська область"
    ]

    // MARK: - Firebase Topic Mapping

    /// Маппінг назви регіону (українською) → Firebase Messaging topic.
    /// Використовується для підписки/відписки від FCM topic notifications.
    public static let topicMapping: [String: String] = [
        "Вінницька область":        "region_vinnytsia",
        "Волинська область":         "region_volyn",
        "Дніпропетровська область":  "region_dnipro",
        "Донецька область":          "region_donetsk",
        "Житомирська область":       "region_zhytomyr",
        "Закарпатська область":      "region_zakarpattya",
        "Запорізька область":        "region_zaporizhzhya",
        "Івано-Франківська область": "region_if",
        "Київська область":          "region_kyiv_oblast",
        "м. Київ":                   "region_kyiv_city",
        "Кіровоградська область":    "region_kirovohrad",
        "Луганська область":         "region_luhansk",
        "Львівська область":         "region_lviv",
        "Миколаївська область":      "region_mykolaiv",
        "Одеська область":           "region_odesa",
        "Полтавська область":        "region_poltava",
        "Рівненська область":        "region_rivne",
        "Сумська область":           "region_sumy",
        "Тернопільська область":     "region_ternopil",
        "Харківська область":        "region_kharkiv",
        "Херсонська область":        "region_kherson",
        "Хмельницька область":       "region_khmelnytskyi",
        "Черкаська область":         "region_cherkasy",
        "Чернівецька область":       "region_chernivtsi",
        "Чернігівська область":      "region_chernihiv"
    ]

    // MARK: - Постійно активні (окуповані) території

    /// Тимчасово окуповані території, які завжди перебувають під тривогою.
    /// Для цих регіонів не генеруються сповіщення про зміну стану.
    public static let permanentlyActiveRegions: Set<String> = [
        "Автономна Республіка Крим",
        "АР Крим",
        "Крим",
        "Луганська область",
        "Луганська обл."
    ]

    /// Перевіряє, чи є регіон постійно активним (окупованим).
    public static func isPermanentlyActive(_ regionName: String) -> Bool {
        permanentlyActiveRegions.contains(regionName)
    }
}
