import SwiftUI

struct PremiumPurchaseCTA: View {
    @ObservedObject var storeManager: StoreKitManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Деталі загрози доступні\nлише з Premium підпискою")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            Text("Отримайте доступ до аналітики загроз, телеметрії руху, прогнозів та хронології подій.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            
            Button(action: {
                Task {
                    if let product = storeManager.storeProducts.first(where: { $0.id.contains("monthly") }) ?? storeManager.storeProducts.first {
                        _ = try? await storeManager.purchase(product)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                    Text("Підключити Premium")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.black)
                .cornerRadius(14)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 15)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.yellow.opacity(0.4), .orange.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
