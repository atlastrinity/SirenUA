import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import OSLog

private let logger = Logger(subsystem: "com.sirenua", category: "PremiumCard")

struct PremiumSettingsCard: View {
    @EnvironmentObject var storeManager: StoreKitManager
    @Binding var isPurchasing: Bool
    let onHaptic: (UIImpactFeedbackGenerator.FeedbackStyle) -> Void

    init(
        isPurchasing: Binding<Bool>,
        onHaptic: @escaping (UIImpactFeedbackGenerator.FeedbackStyle) -> Void
    ) {
        self._isPurchasing = isPurchasing
        self.onHaptic = onHaptic
    }

    var body: some View {
        SettingsCard(title: "SirenUA Premium", icon: "crown.fill", iconColor: Color.siGold) {
            if storeManager.isPremium {
                activePremiumHeader

                StyledDivider()

                VStack(spacing: 8) {
                    ForEach(PremiumFeature.allCases) { feature in
                        PremiumFeatureRow(feature: feature)
                    }
                }
                .padding(.vertical, 4)

                StyledDivider()

                Button(action: {
                    onHaptic(.medium)
                    storeManager.debugResetPremium()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                        Text("Скинути преміум (для тестування)")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ChartColorTheme.overestimated)
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 4)
            } else {
                premiumUpgradeView
            }
        }
    }

    private var activePremiumHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ChartColorTheme.confirmed.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(ChartColorTheme.confirmed)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Premium Активовано")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("Всі 6 преміум можливостей активні")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
    }

    private var premiumUpgradeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Переваги Premium підписки:")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            VStack(spacing: 8) {
                ForEach(PremiumFeature.allCases) { feature in
                    PremiumFeatureRow(feature: feature)
                }
            }

            if let product = storeManager.storeProducts.first(where: { $0.id == "com.sirenua.premium.monthly" }) {
                Button(action: {
                    onHaptic(.medium)
                    isPurchasing = true
                    Task {
                        do { _ = try await PremiumGatekeeper.shared.startPurchase(using: storeManager) }
                        catch { logger.error("Purchase failed: \(error.localizedDescription)") }
                        isPurchasing = false
                    }
                }) {
                    HStack(spacing: 8) {
                        if isPurchasing {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 13))
                            Text("Оформити підписку — \(product.displayPrice)/міс")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.siGold)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                    .shadow(color: Color.siGold.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(isPurchasing)

                Button("Відновити покупки") {
                    onHaptic(.light)
                    Task { await PremiumGatekeeper.shared.restorePurchases(using: storeManager) }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ChartColorTheme.accent)
                .frame(maxWidth: .infinity)
            } else {
                ProgressView("Завантаження продуктів...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }

            StyledDivider()

            Button(action: {
                onHaptic(.medium)
                storeManager.debugEnablePremium()
            }) {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Активувати Premium (для тестування)")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ChartColorTheme.active)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
    }
}
