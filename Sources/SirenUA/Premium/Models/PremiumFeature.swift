import SwiftUI

/// Перелік усіх можливостей та функціоналу SirenUA Premium
enum PremiumFeature: String, CaseIterable, Identifiable {
    /// Хронологія подій та історія тривог по регіонах
    case chronology
    /// Доступ до жовтих/помаранчевих зон загроз на карті та у списках
    case yellowZones
    /// Відображення векторів та траєкторій руху загроз
    case trajectories
    /// Налаштування сповіщень та звукових тоглів для локальних загроз (КАБи, ракети, БПЛА)
    case threatToggles
    /// Розширені деталі загрози та відсоток впевненості ШІ
    case threatDetails
    /// Доступ до сервера загроз та діагностики
    case serverDiagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chronology:
            return "Хронологія подій"
        case .yellowZones:
            return "Жовті зони загроз"
        case .trajectories:
            return "Траєкторії руху"
        case .threatToggles:
            return "Тогли сповіщень загроз"
        case .threatDetails:
            return "Деталізація загроз"
        case .serverDiagnostics:
            return "Моніторинг сервера загроз"
        }
    }

    var subtitle: String {
        switch self {
        case .chronology:
            return "Детальна часова шкала ракетних та авіаційних ризиків"
        case .yellowZones:
            return "Відображення областей з потенційними авіаційними ризиками"
        case .trajectories:
            return "Прогностичні вектори польоту шахедів та ракет"
        case .threatToggles:
            return "Персональне керування звуками та пушами для КАБ/БПЛА"
        case .threatDetails:
            return "Оцінка точності ШІ та оперативна телеметрія"
        case .serverDiagnostics:
            return "Прямий доступ до стану розпізнавання загроз"
        }
    }

    var iconName: String {
        switch self {
        case .chronology:
            return "clock.arrow.circlepath"
        case .yellowZones:
            return "exclamationmark.shield.fill"
        case .trajectories:
            return "arrow.triangle.turn.up.right.diamond.fill"
        case .threatToggles:
            return "bell.badge.waveform.fill"
        case .threatDetails:
            return "eye.fill"
        case .serverDiagnostics:
            return "antenna.radiowaves.left.and.right"
        }
    }

    var accentColor: Color {
        switch self {
        case .chronology:
            return .yellow
        case .yellowZones:
            return .orange
        case .trajectories:
            return .siGold
        case .threatToggles:
            return .siBlue
        case .threatDetails:
            return .green
        case .serverDiagnostics:
            return .cyan
        }
    }
}
