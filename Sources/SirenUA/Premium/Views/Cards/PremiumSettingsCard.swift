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
            // 14-day trial badge
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                Text("14 ДНІВ БЕЗКОШТОВНО")
                    .font(.system(size: 10, weight: .heavy))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.siGold)
            .clipShape(Capsule())

            Text("Переваги Premium підписки:")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            VStack(spacing: 8) {
                ForEach(PremiumFeature.allCases) { feature in
                    PremiumFeatureRow(feature: feature)
                }
            }

            // Subscription Terms Box
            VStack(alignment: .leading, spacing: 6) {
                let priceText = storeManager.storeProducts.first(where: { $0.id == "com.sirenua.premium.monthly" })?.displayPrice ?? "49 ₴"
                Text("14 днів безкоштовно, далі \(priceText)/місяць")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)

                Text("Скасування в будь-який момент у налаштуваннях Apple ID принаймні за 24 години до завершення тріалу — без жодних списань.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.siGold.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.siGold.opacity(0.2), lineWidth: 1)
            )

            Button(action: {
                onHaptic(.medium)
                isPurchasing = true
                Task {
                    do {
                        _ = try await PremiumGatekeeper.shared.startPurchase(using: storeManager)
                    } catch {
                        logger.error("Purchase failed: \(error.localizedDescription)")
                    }
                    await MainActor.run { isPurchasing = false }
                }
            }) {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 13))
                        Text("Спробувати 14 днів безкоштовно")
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
