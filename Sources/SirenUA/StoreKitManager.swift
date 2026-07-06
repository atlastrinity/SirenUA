import Foundation
import StoreKit

typealias Transaction = StoreKit.Transaction
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

@MainActor
class StoreKitManager: ObservableObject {
    
    // Перелік усіх ідентифікаторів продуктів
    private let productIds = ["com.sirenua.premium.monthly"]
    
    @Published var storeProducts: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    
    @Published var isPremium: Bool = false
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    init() {
        // Запускаємо прослуховувач транзакцій
        updateListenerTask = listenForTransactions()
        
        Task {
            // Отримуємо продукти
            await requestProducts()
            // Перевіряємо поточний статус підписок
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // Прослуховувач оновлень від App Store, що відбуваються у фоні (напр. автоматичне поновлення підписки)
    private func listenForTransactions() -> Task<Void, Error> {
        return Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateCustomerProductStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification")
                }
            }
        }
    }
    
    // Завантаження продуктів з App Store (або з локального файлу .storekit)
    func requestProducts() async {
        do {
            let products = try await Product.products(for: productIds)
            self.storeProducts = products
        } catch {
            print("Failed to request products from App Store: \(error)")
        }
    }
    
    // Купівля
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateCustomerProductStatus()
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }
    
    // Перевірка криптографічного підпису транзакції
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // Оновлення статусу всіх покупок користувача
    func updateCustomerProductStatus() async {
        var purchased: [Product] = []
        var hasActivePremium = false
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Перевіряємо, чи підписка є активною
                if transaction.productID == "com.sirenua.premium.monthly" {
                    hasActivePremium = true
                }
                
                if let product = storeProducts.first(where: { $0.id == transaction.productID }) {
                    purchased.append(product)
                }
            } catch {
                print("Failed to verify entitlement: \(error)")
            }
        }
        
        self.purchasedSubscriptions = purchased
        self.isPremium = hasActivePremium
        
        // Також оновлюємо UserDefaults для сумісності зі старим кодом, хоча краще використовувати @EnvironmentObject
        UserDefaults.standard.set(hasActivePremium, forKey: "premiumEnabled")
    }
    
    // Відновлення покупок
    func restorePurchases() async {
        try? await AppStore.sync()
    }
}

enum StoreError: Error {
    case failedVerification
}
