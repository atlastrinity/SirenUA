import Foundation

/// Опис причини блокування фічі для користувачів без Premium
struct PremiumLockReason {
    let feature: PremiumFeature
    let title: String
    let description: String

    init(feature: PremiumFeature) {
        self.feature = feature
        switch feature {
        case .chronology:
            self.title = "Хронологія подій закрита"
            self.description = "Архів подій, активність авіації та детальна історія тривог доступні виключно з Premium підпискою."
        case .yellowZones:
            self.title = "Жовті зони закриті"
            self.description = "Без Premium доступні лише офіційні тривоги (червоні зони). Жовті зони потенційних загроз доступні за Premium підпискою."
        case .trajectories:
            self.title = "Траєкторії руху закриті"
            self.description = "Відображення орієнтовних напрямків польоту ракет і шахедів доступне з Premium підпискою."
        case .threatToggles:
            self.title = "Сповіщення загроз закриті"
            self.description = "Персональні налаштування звуків та сповіщень для КАБів, ракет і БПЛА доступні користувачам Premium."
        case .threatDetails:
            self.title = "Деталі загрози закриті"
            self.description = "Аналітика загрози та оцінка ймовірності від ШІ доступні з Premium підпискою."
        case .serverDiagnostics:
            self.title = "Сервер загроз закритий"
            self.description = "Моніторинг сервера загроз та діагностика доступні з Premium."
        }
    }
}
