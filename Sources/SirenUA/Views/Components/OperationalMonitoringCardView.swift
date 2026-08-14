import SwiftUI

struct OperationalMonitoringCardView: View {
    let regionName: String
    let threatDetail: String?
    let confidence: Int?
    let updatedAt: String
    let isAlarm: Bool
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(isAlarm ? Color.red : Color.yellow)
                        .frame(width: 6, height: 6)
                    
                    Text("НОВЕ ОПЕРАТИВНЕ СПОВІЩЕННЯ")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.cyan)
                        .tracking(1.1)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    (isAlarm ? Color.red : Color.orange).opacity(0.3),
                                    Color.blue.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke((isAlarm ? Color.red : Color.yellow).opacity(0.6), lineWidth: 1)
                        )
                    
                    Image(systemName: isAlarm ? "exclamationmark.triangle.fill" : "bolt.horizontal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isAlarm ? .red : .yellow)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(regionName)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if let conf = confidence {
                            Text("\(conf)%")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Text(threatDetail ?? "Загроза БпЛА (Прогноз): Напрямок Зх/Пд-Зх.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.16, blue: 0.35).opacity(0.30),
                    Color(red: 0.02, green: 0.08, blue: 0.22).opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.cyan.opacity(0.35), .blue.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}
