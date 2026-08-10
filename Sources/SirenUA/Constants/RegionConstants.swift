import Foundation

/// Централізовані константи та утиліти для роботи з регіонами України у додатку SirenUA
public enum RegionConstants {
    /// Тимчасово окуповані території, які завжди перебувають під тривогою (без надсилання сповіщень)
    public static let permanentlyActiveRegions: Set<String> = [
        "Автономна Республіка Крим",
        "АР Крим",
        "Крим",
        "Луганська область",
        "Луганська обл."
    ]

    /// Перевіряє, чи є регіон постійно активним (окупованим)
    public static func isPermanentlyActive(_ regionName: String) -> Bool {
        return permanentlyActiveRegions.contains(regionName)
    }
}
