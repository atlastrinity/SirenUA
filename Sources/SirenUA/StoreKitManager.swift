import Foundation
import StoreKit
import OSLog

private let storeLogger = Logger(subsystem: "com.sirenua", category: "StoreKit")

typealias Transaction = StoreKit.Transaction
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState

@MainActor
final class StoreKitManager: ObservableObject {
    
    // Product IDs List
    private let productIds = ["com.sirenua.premium.monthly"]
    
    @Published var storeProducts: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var isPremium: Bool = false
    
    private var updateListenerTask: Task<Void, Never>? = nil
    
    init() {
        storeLogger.info("StoreKitManager initialized")
        // Start listening to background transaction updates
        updateListenerTask = listenForTransactions()
        
        Task {
            // Request store products
            await requestProducts()
            // Verify current active entitlements
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // Background transaction listener for updates outside the app (e.g. renewals)
    private func listenForTransactions() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    storeLogger.info("Background update verified: \(transaction.productID)")
                    await self.updateCustomerProductStatus()
                    await transaction.finish()
                } catch {
                    storeLogger.error("Background transaction verification failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Fetch products list from App Store or mock configuration
    func requestProducts() async {
        do {
            let products = try await Product.products(for: productIds)
            self.storeProducts = products
            storeLogger.info("App Store loaded \(products.count) products")
        } catch {
            storeLogger.error("Failed to fetch products from App Store: \(error.localizedDescription)")
        }
    }
    
    // Purchase transaction
    func purchase(_ product: Product) async throws -> Transaction? {
        storeLogger.info("Starting purchase flow for \(product.id)")
        
        // Reset mute status when a new purchase is initiated
        UserDefaults.standard.set(false, forKey: "debugPremiumMuted")
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            storeLogger.info("Purchase successful and verified: \(transaction.productID)")
            await updateCustomerProductStatus()
            await transaction.finish()
            return transaction
        case .userCancelled:
            storeLogger.info("User cancelled purchase flow")
            return nil
        case .pending:
            storeLogger.info("Purchase transaction is pending user action")
            return nil
        @unknown default:
            storeLogger.warning("Unknown purchase result encountered")
            return nil
        }
    }
    
    // Verify cryptographic signature of transactions
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            storeLogger.warning("App Store transaction signature could not be verified")
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // Synchronize active entitlements
    func updateCustomerProductStatus() async {
        var purchased: [Product] = []
        var hasActivePremium = false
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productID == "com.sirenua.premium.monthly" {
                    hasActivePremium = true
                }
                
                if let product = storeProducts.first(where: { $0.id == transaction.productID }) {
                    purchased.append(product)
                }
            } catch {
                storeLogger.error("Entitlement verification failed: \(error.localizedDescription)")
            }
        }
        
        // If debug premium is muted, override and force false
        if UserDefaults.standard.bool(forKey: "debugPremiumMuted") {
            hasActivePremium = false
        }
        
        self.purchasedSubscriptions = purchased
        self.isPremium = hasActivePremium
        
        storeLogger.info("Entitlements status updated: premium=\(hasActivePremium)")
        
        // Sync with UserDefaults for backward compatibility
        UserDefaults.standard.set(hasActivePremium, forKey: "premiumEnabled")
    }
    
    // Restore Purchases
    func restorePurchases() async {
        storeLogger.info("Manually syncing purchases with App Store...")
        UserDefaults.standard.set(false, forKey: "debugPremiumMuted")
        do {
            try await AppStore.sync()
            await updateCustomerProductStatus()
        } catch {
            storeLogger.error("Failed to restore purchases: \(error.localizedDescription)")
        }
    }
    
    // Debug Reset for testers
    func debugResetPremium() {
        storeLogger.info("Resetting premium for testing purposes")
        UserDefaults.standard.set(true, forKey: "debugPremiumMuted")
        Task {
            await updateCustomerProductStatus()
        }
    }
}

// MARK: - StoreError

enum StoreError: LocalizedError {
    case failedVerification
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Не вдалося перевірити підпис транзакції в App Store."
        }
    }
}
