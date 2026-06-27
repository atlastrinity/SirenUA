import SwiftUI

@available(iOS 17.0, *)
struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            
            Text("Something went wrong")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
            
            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            
            Button("Try Again") {
                NotificationCenter.default.post(name: .refreshAlerts, object: nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

extension Notification.Name {
    static let refreshAlerts = Notification.Name("refreshAlerts")
}
