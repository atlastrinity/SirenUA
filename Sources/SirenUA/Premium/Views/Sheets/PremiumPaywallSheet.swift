import SwiftUI
import StoreKit
#if canImport(UIKit)
import UIKit
#endif
import OSLog

private let paywallLogger = Logger(subsystem: "com.sirenua", category: "Paywall")

/// Уніфіковане вікно оформлення SirenUA Premium із 14-денним безкоштовним періодом
struct PremiumPaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreKitManager
    
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // Dark sleek background
            Color(red: 0.05, green: 0.06, blue: 0.10)
                .ignoresSafeArea()

            // Subtle gold & blue glow in background
            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .fill(Color.siGold.opacity(0.12))
                        .frame(width: 320, height: 320)
                        .blur(radius: 80)
                        .offset(x: proxy.size.width * 0.2, y: -60)

                    Circle()
                        .fill(Color.siBlue.opacity(0.10))
                        .frame(width: 280, height: 280)
                        .blur(radius: 70)
                        .offset(x: -proxy.size.width * 0.25, y: 150)
                }
            }
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                        .padding(.top, 12)

                    featuresSection

                    subscriptionTermsBox

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    ctaButtonsSection
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: storeManager.isPremium) { _, isPremium in
            if isPremium {
                paywallLogger.info("Premium activated, auto-dismissing paywall sheet")
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                dismiss()
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button(action: {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Crown Icon with glow
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.siGold.opacity(0.25), Color.siGold.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.siGold.opacity(0.4), lineWidth: 1.5)
                    )

                Image(systemName: "crown.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.siGold, Color.yellow],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.siGold.opacity(0.5), radius: 10, x: 0, y: 3)
            }

            // Trial badge
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text("14 ДНІВ БЕЗКОШТОВНО")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.5)
            }
            .foregroundColor(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [Color.siGold, Color.yellow],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: Color.siGold.opacity(0.4), radius: 6, x: 0, y: 2)

            Text("SirenUA Premium")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            Text("Отримайте максимальний захист та розширений моніторинг повітряних загроз у реальному часі.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 10)
        }
    }

    // MARK: - Features List
    private var featuresSection: some View {
        VStack(spacing: 10) {
            featureRow(
                icon: "bell.badge.waveform.fill",
                title: "Локальні сповіщення про загрози",
                subtitle: "Миттєві пуші про ракети, КАБи та дрони для вашого регіону",
                color: Color.siBlue
            )

            featureRow(
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                title: "Траєкторії та вектори руху",
                subtitle: "Напрямки польоту та прогностичні коридори на 3D-карті",
                color: Color.siGold
            )

            featureRow(
                icon: "exclamationmark.shield.fill",
                title: "Зони підвищеної небезпеки",
                subtitle: "Відображення наближення авіаційних та балістичних загроз",
                color: Color.orange
            )

            featureRow(
                icon: "clock.arrow.circlepath",
                title: "Хронологія та аналітика ШІ",
                subtitle: "Повна історія подій та оцінка впевненості розпізнавання цілей",
                color: Color.yellow
            )

            featureRow(
                icon: "speaker.wave.3.fill",
                title: "Індивідуальні звуки та вібрація",
                subtitle: "Окреме налаштування аудіосигналів для кожного типу небезпеки",
                color: Color.green
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func featureRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
            }

            Spacer()
        }
    }

    // MARK: - Subscription Terms Box (App Store Guideline 3.1.2 compliant)
    private var subscriptionTermsBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(Color.siGold)
                    .font(.system(size: 16))
                
                let priceText = storeManager.storeProducts.first(where: { $0.id == "com.sirenua.premium.monthly" })?.displayPrice ?? "49 ₴"
                Text("14 днів безкоштовно, далі \(priceText)/місяць")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("• **Безкоштовно перші 14 днів.** Ви можете скасувати підписку в будь-який момент у налаштуваннях Apple ID принаймні за 24 години до завершення пробного періоду — **без жодних списань та оплат**.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.75))
                .lineSpacing(3)

            Text("• Оплата списується з вашого облікового запису Apple ID лише після завершення 14 днів безкоштовного доступу. Підписка поновлюється автоматично щомісяця, якщо її не скасовано.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.55))
                .lineSpacing(2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.siGold.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.siGold.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - CTA & Secondary Buttons
    private var ctaButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                startPurchaseFlow()
            }) {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                        Text("Спробувати 14 днів безкоштовно")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.siGold, Color.yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.siGold.opacity(0.4), radius: 12, x: 0, y: 4)
            }
            .disabled(isPurchasing || isRestoring)

            Button(action: {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                restorePurchasesFlow()
            }) {
                if isRestoring {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Відновити покупки")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .underline()
                }
            }
            .disabled(isPurchasing || isRestoring)
            .padding(.top, 4)

            // Legal Links (EULA & Privacy Policy)
            HStack(spacing: 16) {
                Link("Умови використання (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))

                Text("•")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))

                Link("Політика конфіденційності", destination: URL(string: "https://sirenua.com/privacy")!)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Purchase Actions
    private func startPurchaseFlow() {
        isPurchasing = true
        errorMessage = nil

        Task {
            do {
                let success = try await PremiumGatekeeper.shared.startPurchase(using: storeManager)
                await MainActor.run {
                    isPurchasing = false
                    if success {
                        #if canImport(UIKit)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        #endif
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    #endif
                }
            }
        }
    }

    private func restorePurchasesFlow() {
        isRestoring = true
        errorMessage = nil

        Task {
            await PremiumGatekeeper.shared.restorePurchases(using: storeManager)
            await MainActor.run {
                isRestoring = false
                if storeManager.isPremium {
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                    dismiss()
                } else {
                    errorMessage = "Активних підписок не знайдено."
                }
            }
        }
    }
}
