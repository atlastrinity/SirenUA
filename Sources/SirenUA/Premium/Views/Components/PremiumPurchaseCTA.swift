import SwiftUI

/// Картка заклику до покупки Premium підписки
struct PremiumPurchaseCTA: View {
    @ObservedObject var storeManager: StoreKitManager
    var title: String
    var feature: PremiumFeature

    init(
        storeManager: StoreKitManager,
        title: String = "Деталі загрози доступні\nлише з Premium підпискою",
        feature: PremiumFeature = .threatDetails
    ) {
        self.storeManager = storeManager
        self.title = title
        self.feature = feature
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: feature.iconName)
                .font(.system(size: 28))
                .foregroundColor(feature.accentColor)

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(feature.subtitle)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button(action: {
                Task {
                    _ = try? await PremiumGatekeeper.shared.startPurchase(using: storeManager)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13))
                    Text("Підключити Premium")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(feature.accentColor)
                .cornerRadius(12)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(feature.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}
