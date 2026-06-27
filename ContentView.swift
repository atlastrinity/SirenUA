import SwiftUI
import MapKit

@available(iOS 17.0, *)
struct ContentView: View {
    @StateObject private var viewModel = AlertViewModel()
    @State private var selectedAlert: Alert?

    var body: some View {
        ZStack {
            // Карта України
            MapView(alerts: viewModel.alerts, selectedAlert: $selectedAlert)
                .edgesIgnoringSafeArea(.all)

            // Картка статусу внизу екрана
            AlertStatusCard(
                activeCount: viewModel.activeAlertsCount,
                lastUpdated: viewModel.lastUpdated
            )
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(radius: 10)

            // Детальний вигляд при виборі тривоги
            if let selectedAlert = selectedAlert {
                AlertDetailView(alert: selectedAlert)
                    .transition(.move(edge: .bottom))
            }
        }
        .navigationTitle("SirenUA - Air Raid Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

@available(iOS 17.0, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
