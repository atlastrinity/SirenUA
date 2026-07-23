import SwiftUI

struct OperationalMonitoringCardView: View {
    let regionName: String
    let threatDetail: String?
    let confidence: Int?
    let updatedAt: String
    let isAlarm: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ОПЕРАТИВНИЙ МОНІТОРИНГ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.2)
                Spacer()
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            HStack(alignment: .top, spacing: 12) {
                // Trajectory Badge Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isAlarm ? Color.red.opacity(0.2) : Color.yellow.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isAlarm ? Color.red.opacity(0.5) : Color.yellow.opacity(0.5), lineWidth: 1)
                        )
                    
                    Image(systemName: isAlarm ? "exclamationmark.triangle.fill" : "arrow.up.right.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isAlarm ? .red : .yellow)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(regionName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(threatDetail ?? "Загроза БпЛА (Прогноз): Напрямок Зх/Пд-Зх. Ймовірність \(confidence ?? 92)%.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                    
                    Text("Останнє оновлення: \(updatedAt)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(
            Color(red: 0.08, green: 0.11, blue: 0.16).opacity(0.88)
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 16)
    }
}
