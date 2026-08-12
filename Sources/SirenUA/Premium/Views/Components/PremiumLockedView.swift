import SwiftUI

/// Уніфікований стек блокування фічі з прозорим склоподібним інтерфейсом
struct PremiumLockedView: View {
    let feature: PremiumFeature
    @EnvironmentObject private var storeManager: StoreKitManager
    @State private var isPurchasing = false

    init(feature: PremiumFeature) {
        self.feature = feature
    }

    private var lockReason: PremiumLockReason {
        PremiumLockReason(feature: feature)
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(feature.accentColor.opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: feature.iconName)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(feature.accentColor)

                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .offset(x: 26, y: -26)
            }
            .padding(.top, 10)

            VStack(spacing: 8) {
                Text(lockReason.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(lockReason.description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
            }

            Button(action: {
                triggerPurchase()
            }) {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 15))
                        Text("Підключити Premium")
                            .font(.system(size: 15, weight: .bold))
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [feature.accentColor, feature.accentColor.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: feature.accentColor.opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .disabled(isPurchasing)
            .padding(.horizontal, 20)

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
            .padding(.bottom, 10)
        }
        .padding(24)
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
