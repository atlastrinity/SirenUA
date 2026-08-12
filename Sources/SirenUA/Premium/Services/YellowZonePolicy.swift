import Foundation

/// Сервіс розрахунку та фільтрації жовтих зон загроз відповідно до преміум-статусу
struct YellowZonePolicy {

    /// Повертає масив жовтих/помаранчевих зон потенційних загроз.
    /// Якщо у користувача НЕМАЄ Premium (або доступу до `.yellowZones`), повертається ПОРОЖНІЙ масив.
    static func filterActiveThreatRegions(
        allRegions: [RegionPolygon],
        alertsDict: [String: AlertRegion],
        isPremium: Bool
    ) -> [RegionPolygon] {
        guard isPremium else { return [] }

        return allRegions
            .filter { region in
                guard let alert = alertsDict[region.nameUK] else { return false }
                return !alert.isActive && (alert.threatLevel != nil || !alert.activeThreats.isEmpty)
            }
            .sorted { r1, r2 in
                if r1.nameUK == "м. Київ" { return false }
                if r2.nameUK == "м. Київ" { return true }
                return r1.nameUK < r2.nameUK
            }
    }

    /// Повертає масив безпечних регіонів.
    /// Для не-преміум користувачів усі регіони без ОФІЦІЙНОЇ тривоги (`!alert.isActive`) вважаються безпечними.
    static func filterSafeRegions(
        allRegions: [RegionPolygon],
        alertsDict: [String: AlertRegion],
        isPremium: Bool
    ) -> [RegionPolygon] {
        return allRegions
            .filter { region in
                guard let alert = alertsDict[region.nameUK] else { return true }
                if isPremium {
                    // Для Premium: область безпечна, якщо немає ні офіційної тривоги, ні локальної загрози
                    return !alert.isActive && alert.threatLevel == nil && alert.activeThreats.isEmpty
                } else {
                    // Для не-Premium: область безпечна, якщо немає ОФІЦІЙНОЇ тривоги
                    return !alert.isActive
                }
            }
            .sorted { r1, r2 in
                if r1.nameUK == "м. Київ" { return false }
                if r2.nameUK == "м. Київ" { return true }
                return r1.nameUK < r2.nameUK
            }
    }
}
