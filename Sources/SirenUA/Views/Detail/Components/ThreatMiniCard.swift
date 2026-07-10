import SwiftUI

struct ThreatMiniCard: View {
    let threat: SingleThreatInfo
    let isSelected: Bool
    let themeColor: Color
    let timeRefreshTrigger: Date

    var body: some View {
        let _ = timeRefreshTrigger
        HStack(spacing: 6) {
            Image(systemName: threat.threatIcon)
                .font(.system(size: 14, weight: .bold))
            Text(threat.threatLabel)
                .font(.system(size: 13, weight: .semibold))
            if let eta = threat.dynamicETA, !eta.isEmpty {
                Text("(\(eta))")
                    .font(.system(size: 11))
                    .opacity(0.7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? themeColor.opacity(0.2) : Color.white.opacity(0.05))
        .foregroundStyle(isSelected ? themeColor : .white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? themeColor : Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
