import SwiftUI

struct AlertPinViewV4: View {
    let alert: AlertRegion
    var isPulsating: Bool
    
    var body: some View {
        ZStack {
            if alert.level >= 3 {
                Circle()
                    .fill(alert.color.opacity(0.4))
                    .frame(width: isPulsating ? 80 : 20)
                    .opacity(isPulsating ? 0 : 1)
                    .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: isPulsating)
            }
            
            Image(systemName: alert.icon)
                .font(.caption)
                .foregroundColor(.white)
                .padding(6)
                .background(alert.color)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                .shadow(radius: 4)
        }
    }
}
