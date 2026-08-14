import Foundation
import CoreLocation

/// Єдиний реєстр регіонів України для всього додатку SirenUA.
///
/// Містить:
/// - Канонічний список усіх 25 областей/міст
/// - Firebase topic mapping (регіон → FCM topic)
/// - Координати центроїдів областей
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

    // MARK: - Координати центроїдів областей

    public static let regionalCoordinates: [String: CLLocationCoordinate2D] = [
        "Вінницька область":         CLLocationCoordinate2D(latitude: 49.2331, longitude: 28.4682),
        "Волинська область":          CLLocationCoordinate2D(latitude: 50.7412, longitude: 25.3201),
        "Дніпропетровська область":   CLLocationCoordinate2D(latitude: 48.4647, longitude: 35.0462),
        "Донецька область":           CLLocationCoordinate2D(latitude: 48.0159, longitude: 37.8028),
        "Житомирська область":        CLLocationCoordinate2D(latitude: 50.2547, longitude: 28.6587),
        "Закарпатська область":       CLLocationCoordinate2D(latitude: 48.6208, longitude: 22.2879),
        "Запорізька область":         CLLocationCoordinate2D(latitude: 47.8388, longitude: 35.1396),
        "Івано-Франківська область":  CLLocationCoordinate2D(latitude: 48.9226, longitude: 24.7111),
        "Київська область":           CLLocationCoordinate2D(latitude: 50.0500, longitude: 30.1500),
        "м. Київ":                    CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234),
        "Кіровоградська область":     CLLocationCoordinate2D(latitude: 48.5079, longitude: 32.2623),
        "Луганська область":          CLLocationCoordinate2D(latitude: 48.5740, longitude: 39.3078),
        "Львівська область":          CLLocationCoordinate2D(latitude: 49.8397, longitude: 24.0297),
        "Миколаївська область":       CLLocationCoordinate2D(latitude: 46.9750, longitude: 31.9946),
        "Одеська область":            CLLocationCoordinate2D(latitude: 46.4825, longitude: 30.7233),
        "Полтавська область":         CLLocationCoordinate2D(latitude: 49.5883, longitude: 34.5514),
        "Рівненська область":         CLLocationCoordinate2D(latitude: 50.6199, longitude: 26.2516),
        "Сумська область":            CLLocationCoordinate2D(latitude: 50.9077, longitude: 34.7981),
        "Тернопільська область":      CLLocationCoordinate2D(latitude: 49.5535, longitude: 25.5948),
        "Харківська область":         CLLocationCoordinate2D(latitude: 49.9935, longitude: 36.2304),
        "Херсонська область":         CLLocationCoordinate2D(latitude: 46.6354, longitude: 32.6169),
        "Хмельницька область":        CLLocationCoordinate2D(latitude: 49.4230, longitude: 26.9871),
        "Черкаська область":          CLLocationCoordinate2D(latitude: 49.4444, longitude: 32.0598),
        "Чернівецька область":        CLLocationCoordinate2D(latitude: 48.2915, longitude: 25.9352),
        "Чернігівська область":       CLLocationCoordinate2D(latitude: 51.4982, longitude: 31.2893),
        "Автономна Республіка Крим":  CLLocationCoordinate2D(latitude: 45.3000, longitude: 34.1000),
        "АР Крим":                    CLLocationCoordinate2D(latitude: 45.3000, longitude: 34.1000)
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
