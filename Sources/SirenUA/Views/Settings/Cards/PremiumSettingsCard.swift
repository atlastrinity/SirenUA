import SwiftUI
import UIKit
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

    public var body: some View {
        SettingsCard(title: "SirenUA Premium", icon: "crown.fill", iconColor: Color.yellow) {
            if storeManager.isPremium {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(ChartColorTheme.confirmed)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Premium Активовано")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text("Всі функції розблоковано")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                }
                StyledDivider()
                Button(action: {
                    storeManager.debugResetPremium()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                        Text("Скинути преміум (для тестування)")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ChartColorTheme.overestimated)
                }
                .padding(.vertical, 4)
            } else {
                premiumUpgradeView
            }
        }
    }

    private var premiumUpgradeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Розширені можливості:")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            VStack(spacing: 8) {
                premiumFeatureRow(icon: "antenna.radiowaves.left.and.right", text: "Моніторинг загроз (Сервер)", color: ChartColorTheme.accent)
                premiumFeatureRow(icon: "eye.fill",                          text: "Деталізація загроз",         color: ChartColorTheme.active)
            }

            if let product = storeManager.storeProducts.first(where: { $0.id == "com.sirenua.premium.monthly" }) {
                Button(action: {
                    isPurchasing = true
                    Task {
                        do { _ = try await storeManager.purchase(product) }
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
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isPurchasing)

                Button("Відновити покупки") {
                    Task { await storeManager.restorePurchases() }
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

    private func premiumFeatureRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
