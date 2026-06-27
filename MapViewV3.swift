import SwiftUI
import MapKit

@available(iOS 17.0, *)
struct AlertPin: Identifiable {
    let id: Int
    let coordinate: CLLocationCoordinate2D
    let title: String
    let isActive: Bool
    let level: Int

    var color: Color {
        if isActive {
            return level >= 4 ? .red : (level >= 3 ? .orange : .yellow)
        } else {
            return .green
        }
    }

    var icon: String {
        isActive ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }
}

@available(iOS 17.0, *)
struct MapViewV3: View {
    @StateObject private var viewModel: AlertViewModelV3
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 49.0, longitude: 31.0),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )
    @State private var selectedAlert: AlertRegion?

    init(viewModel: AlertViewModelV3) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(coordinateRegion: $region, annotationItems: viewModel.alerts) { alert in
                MapAnnotation(coordinate: alert.coordinate) {
                    AlertPinView(alert: alert)
                }
            }
            .edgesIgnoringSafeArea(.all)

            // Status card overlay
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(viewModel.activeAlerts > 0 ? Color.red : Color.green)
                        .frame(width: 12, height: 12)
                        .shadow(radius: 4)
                    Text("\(viewModel.activeAlerts) активних тривог")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                )

                // Level indicators
                HStack(spacing: 8) {
                    ForEach(1..<5) { level in
                        Circle()
                            .fill(level <= viewModel.maxLevel ? .red : .gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                )
            }
            .padding()

            // Filter buttons
            VStack(alignment: .trailing, spacing: 12) {
                Button(action: {
                    withAnimation {
                        viewModel.showAllAlerts = true
                    }
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .symbolEffect(.bounce, value: viewModel.showAllAlerts)
                        .padding(12)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .shadow(color: .black.opacity(0.15), radius: 15, y: 8)
                .sensoryFeedback(.impact, trigger: viewModel.showAllAlerts)

                Button(action: {
                    withAnimation {
                        viewModel.showAllAlerts = false
                    }
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(.white)
                        .symbolEffect(.bounce, value: viewModel.showAllAlerts)
                        .padding(12)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .shadow(color: .black.opacity(0.15), radius: 15, y: 8)
                .sensoryFeedback(.impact, trigger: viewModel.showAllAlerts)
            }
            .padding()
        }
        .sheet(item: $selectedAlert) { alert in
            AlertRegionDetailView(region: alert)
        }
    }
}

@available(iOS 17.0, *)
struct AlertPinView: View {
    let alert: AlertRegion

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: alert.icon)
                .font(.title2)
                .foregroundColor(alert.color)
                .symbolEffect(.pulse, isActive: alert.isActive)
                .shadow(radius: 2)

            if alert.isActive {
                Text("\(alert.level)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(alert.color))
            }
        }
        .onTapGesture {
            // Tap handled by MapView
        }
    }
}

@available(iOS 17.0, *)
struct MapViewV3_Previews: PreviewProvider {
    static var previews: some View {
        MapViewV3(viewModel: AlertViewModelV3())
    }
}
