import Foundation
import Combine
import OSLog

private let gatekeeperLogger = Logger(subsystem: "com.sirenua", category: "PremiumGatekeeper")

/// Менеджер розмежування доступу до преміум-функцій SirenUA
@MainActor
final class PremiumGatekeeper: ObservableObject {
    static let shared = PremiumGatekeeper()

    @Published private(set) var isPremium: Bool = false
    private var cancellables = Set<AnyCancellable>()

    private init() {
        updatePremiumStatus()
        
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updatePremiumStatus()
            }
            .store(in: &cancellables)
    }

    /// Синхронізація стану підписки з UserDefaults та відлагоджувальними прапорами
    func updatePremiumStatus() {
        let muted = UserDefaults.standard.bool(forKey: "debugPremiumMuted")
        let forced = UserDefaults.standard.bool(forKey: "debugPremiumEnabled")
        let stored = UserDefaults.standard.bool(forKey: "premiumEnabled")

        let newStatus: Bool
        if muted {
            newStatus = false
        } else if forced {
            newStatus = true
        } else {
            newStatus = stored
        }

        if isPremium != newStatus {
            isPremium = newStatus
            UserDefaults(suiteName: NotificationSettings.suiteName)?.set(newStatus, forKey: "premiumEnabled")
            NotificationSettings.shared.isPremium = newStatus
            gatekeeperLogger.info("PremiumGatekeeper status updated: isPremium=\(newStatus)")
        }
    }

    /// Головний метод перевірки доступу до специфічної фічі
    func canAccess(_ feature: PremiumFeature) -> Bool {
        // Якщо користувач має підписку, він отримує доступ до всіх преміум фіч
        guard isPremium else { return false }
        return true
    }

    /// Причини блокування для виведення в UI
    func lockReason(for feature: PremiumFeature) -> PremiumLockReason {
        PremiumLockReason(feature: feature)
    }

    // MARK: - Centralized Purchase Pipeline

    /// Єдиний централізований метод виконання або запуску покупки Premium для будь-якого екрана/фічі
    @discardableResult
    func startPurchase(using storeManager: StoreKitManager) async throws -> Bool {
        gatekeeperLogger.info("Initiating purchase through central PremiumGatekeeper module...")

        // Якщо в StoreKit вже завантажено продукт
        if let product = storeManager.storeProducts.first(where: { $0.id == "com.sirenua.premium.monthly" }) {
            let transaction = try await storeManager.purchase(product)
            updatePremiumStatus()
            return transaction != nil
        } else {
            // Резервний запуск / тестування без конфігурації App Store
            gatekeeperLogger.info("No App Store product loaded — activating debug premium status via central module")
            storeManager.debugEnablePremium()
            updatePremiumStatus()
            return true
        }
    }

    /// Єдиний централізований метод відновлення покупок
    func restorePurchases(using storeManager: StoreKitManager) async {
        gatekeeperLogger.info("Initiating restore purchases through central PremiumGatekeeper module...")
        await storeManager.restorePurchases()
        updatePremiumStatus()
    }
}
