import SwiftUI

/// Картка заклику до покупки Premium підписки
struct PremiumPurchaseCTA: View {
    @ObservedObject var storeManager: StoreKitManager
    var title: String
    var feature: PremiumFeature

    @State private var showPaywallSheet = false

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
        VStack(spacing: 10) {
            // 14-day trial badge
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .bold))
                Text("14 ДНІВ БЕЗКОШТОВНО")
                    .font(.system(size: 9, weight: .heavy))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.siGold)
            .clipShape(Capsule())

            Image(systemName: feature.iconName)
                .font(.system(size: 26))
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
                showPaywallSheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13))
                    Text("Спробувати 14 днів безкоштовно")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.siGold, Color.yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: Color.siGold.opacity(0.35), radius: 6, x: 0, y: 2)
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
        .sheet(isPresented: $showPaywallSheet) {
            PremiumPaywallSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
