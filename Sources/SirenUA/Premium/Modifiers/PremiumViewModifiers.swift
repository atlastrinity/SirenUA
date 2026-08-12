import SwiftUI

struct PremiumFeatureGateModifier: ViewModifier {
    let feature: PremiumFeature
    @ObservedObject private var gatekeeper = PremiumGatekeeper.shared

    init(feature: PremiumFeature) {
        self.feature = feature
    }

    func body(content: Content) -> some View {
        if gatekeeper.canAccess(feature) {
            content
        } else {
            PremiumLockedView(feature: feature)
        }
    }
}

extension View {
    /// Блокує контент за допомогою `PremiumLockedView`, якщо фіча не оплачена
    func premiumFeatureGate(_ feature: PremiumFeature) -> some View {
        self.modifier(PremiumFeatureGateModifier(feature: feature))
    }

    /// Накладає ефект відключення та блокування, якщо користувач не має Premium
    func premiumDisabled(_ isNonPremium: Bool, onLockedTap: (() -> Void)? = nil) -> some View {
        self
            .disabled(isNonPremium)
            .opacity(isNonPremium ? 0.5 : 1.0)
            .onTapGesture {
                if isNonPremium {
                    onLockedTap?()
                }
            }
    }
}
