import SwiftUI

/// Уніфікований стек блокування фічі з прозорим склоподібним інтерфейсом
struct PremiumLockedView: View {
    let feature: PremiumFeature
    @EnvironmentObject private var storeManager: StoreKitManager
    @State private var isPurchasing = false

    @State private var showPaywallSheet = false

    init(feature: PremiumFeature) {
        self.feature = feature
    }

    private var lockReason: PremiumLockReason {
        PremiumLockReason(feature: feature)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Trial badge
            HStack(spacing: 5) {
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
            .padding(.top, 6)

            ZStack {
                Circle()
                    .fill(feature.accentColor.opacity(0.12))
                    .frame(width: 70, height: 70)

                Image(systemName: feature.iconName)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(feature.accentColor)

                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .offset(x: 22, y: -22)
            }

            VStack(spacing: 6) {
                Text(lockReason.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(lockReason.description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 12)
            }

            // Subscription Terms snippet
            VStack(spacing: 3) {
                let priceText = storeManager.storeProducts.first(where: { $0.id == "com.sirenua.premium.monthly" })?.displayPrice ?? "49 ₴"
                Text("14 днів безкоштовно, далі \(priceText)/міс")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.siGold)
                Text("Скасування в будь-який час без оплат")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 2)

            Button(action: {
                showPaywallSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                    Text("Спробувати 14 днів безкоштовно")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(
                        colors: [Color.siGold, Color.yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: Color.siGold.opacity(0.35), radius: 8, x: 0, y: 3)
            }
            .padding(.horizontal, 16)

            Button(action: {
                Task {
                    await PremiumGatekeeper.shared.restorePurchases(using: storeManager)
                }
            }) {
                Text("Відновити покупки")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .underline()
            }
            .padding(.bottom, 6)
        }
        .padding(20)
        .sheet(isPresented: $showPaywallSheet) {
            PremiumPaywallSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.07, green: 0.09, blue: 0.15).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [feature.accentColor.opacity(0.5), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .padding(.horizontal, 20)
    }

    private func triggerPurchase() {
        isPurchasing = true
        Task {
            _ = try? await PremiumGatekeeper.shared.startPurchase(using: storeManager)
            isPurchasing = false
        }
    }
}
