import SwiftUI

struct AIRadarHeroCardView: View {
    let primaryRegion: String
    let activeThreatCount: Int
    let isAlarmActive: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Top Bar: Brand, Logo, Location
            HStack {
                Text("SirenUA")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                HStack(spacing: 5) {
                    Image(systemName: "dot.radiowaves.up.forward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("Siren")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(primaryRegion.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            
            // Hero Blue Gradient Box
            VStack(spacing: 4) {
                Text("ШІ-РАДАР ПОВІТРЯНИХ ЗАГРОЗ")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .white],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .cyan.opacity(0.5), radius: 8)
                
                Text("Прогнозування векторів БпЛА та ракет")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                // Page Dots
                HStack(spacing: 6) {
                    Circle().fill(Color.cyan).frame(width: 5, height: 5)
                    Circle().fill(Color.white.opacity(0.3)).frame(width: 5, height: 5)
                    Circle().fill(Color.white.opacity(0.3)).frame(width: 5, height: 5)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.18, blue: 0.32).opacity(0.9),
                        Color(red: 0.04, green: 0.08, blue: 0.16).opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan.opacity(0.6), .blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)
        }
    }
}
