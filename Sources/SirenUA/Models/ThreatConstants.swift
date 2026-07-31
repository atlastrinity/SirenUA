import SwiftUI

/// Єдині константи та реєстр об'єктів загрози (прильоту/вильоту) для всього клієнтського додатку.
public enum ThreatConstants {
    // 1. Строкові ідентифікатори загроз
    public static let shahed = "shahed"
    public static let cruiseMissile = "cruise_missile"
    public static let ballistic = "ballistic"
    public static let mig31k = "mig31k"
    public static let kab = "kab"
    public static let tu95 = "tu95"
    public static let iskander = "iskander"
    public static let artillery = "artillery"
    public static let recon = "recon"
    public static let reconUav = "recon_uav"
    public static let unknown = "unknown"

    // 2. Назви українською
    public static func title(for threatType: String?) -> String {
        guard let threatType = threatType?.lowercased() else { return "Повітряна тривога" }
        switch threatType {
        case shahed: return "БпЛА «Шахед»"
        case cruiseMissile: return "Крилаті ракети"
        case ballistic: return "Балістична ракета"
        case mig31k: return "МіГ-31К (Кинджал)"
        case kab: return "Керовані авіабомби (КАБ)"
        case tu95: return "Ту-95МС"
        case iskander: return "Іскандер-М"
        case artillery: return "Артилерійський обстріл"
        case recon, reconUav: return "Розвідувальний БпЛА"
        default: return "Повітряна загроза"
        }
    }

    // 3. Emoji іконки
    public static func emoji(for threatType: String?) -> String {
        guard let threatType = threatType?.lowercased() else { return "⚠️" }
        switch threatType {
        case shahed: return "🛩"
        case cruiseMissile: return "🚀"
        case ballistic: return "💥"
        case mig31k: return "🛫"
        case kab: return "💣"
        case tu95: return "✈️"
        case iskander: return "🎯"
        case artillery: return "💥"
        default: return "⚠️"
        }
    }

    // 4. SF Symbol іконки
    public static func sfSymbol(for threatType: String?) -> String {
        guard let threatType = threatType?.lowercased() else { return "exclamationmark.triangle.fill" }
        switch threatType {
        case shahed: return "airplane"
        case cruiseMissile: return "bolt.fill"
        case ballistic: return "arrow.up.right"
        case mig31k: return "airplane"
        case kab: return "flame.fill"
        case tu95: return "airplane.circle.fill"
        case iskander: return "scope"
        case artillery: return "burst.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }

    // 5. Кольори загроз
    public static func color(for threatType: String?) -> Color {
        guard let threatType = threatType?.lowercased() else { return .orange }
        switch threatType {
        case shahed: return .yellow
        case cruiseMissile: return .red
        case ballistic, iskander, mig31k: return .purple
        case kab: return .orange
        case tu95: return .red
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
        case artillery: return 1200.0
        case recon, reconUav: return 120.0
        default: return 300.0
        }
    }
}
