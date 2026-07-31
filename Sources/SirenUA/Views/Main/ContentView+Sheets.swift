import SwiftUI
import MapKit

// MARK: - Sheet Content & Navigation Helpers
extension ContentView {

    // MARK: Sheet builder

    @ViewBuilder
    func sheetContent(for item: ActiveSheet) -> some View {
        switch item {
        case .settings:
            SettingsView()
                .presentationBackground(.clear)

        case .admin:
            AdminDashboardView()

        case .share:
            let shareText: String = {
                if let shelter = mapViewModel.foundShelter {
                    let lat = shelter.placemark.coordinate.latitude
                    let lon = shelter.placemark.coordinate.longitude
                    let name = shelter.name ?? ""
                    return "🚨 Увага! Повітряна тривога.\nЗнайдено найближче укриття: \(name)\nКоординати: \(String(format: "%.5f", lat)), \(String(format: "%.5f", lon))"
                } else {
                    return "🚨 Увага! Повітряна тривога.\nЗнайдіть найближче безпечне місце."
                }
            }()
            ShareSheet(activityItems: [shareText])

        case .shelterDetail(let shelter):
            if !mapViewModel.isNavigating {
                ShelterDetailView(
                    shelter: shelter,
                    route: mapViewModel.route,
                    isCalculatingRoute: mapViewModel.isCalculatingRoute,
                    routeErrorMessage: mapViewModel.routeErrorMessage,
                    onRouteRequested: {
                        mapViewModel.calculateRoute(from: currentUserCoordinate, to: shelter)
                    },
                    onStartNavigation: {
                        mapViewModel.isNavigating = true
                        mapViewModel.activeSheet = nil

                        if mapViewModel.route != nil {
                            withAnimation(.easeInOut(duration: 2.0)) {
                                let coord = currentUserCoordinate
                                mapViewModel.cameraPosition = .userLocation(
                                    followsHeading: true,
                                    fallback: .camera(MapCamera(centerCoordinate: coord, distance: 400, heading: 0, pitch: 60))
                                )
                            }
                        } else {
                            let coord = currentUserCoordinate
                            mapViewModel.cameraPosition = .userLocation(
                                fallback: .camera(MapCamera(centerCoordinate: coord, distance: 1000, heading: 0, pitch: 0))
                            )
                        }
                    }
                )
                .presentationDetents([.height(220)])
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(24)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(220)))
                .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: Notification handler

    func handleOpenRegionDetail(_ notification: Notification) {
        guard let regionName = notification.userInfo?["regionName"] as? String else { return }
        Task {
            await viewModel.fetchThreatState()
            await MainActor.run {
                if let region = viewModel.alerts.first(where: { $0.name == regionName }) {
                    mapViewModel.selectedRegionForDetail = region
                }
            }
        }
    }

    // MARK: Location button

    var locationButton: some View {
        Button(action: {
            let coord = currentUserCoordinate
            withAnimation(.easeInOut(duration: 1.0)) {
                mapViewModel.cameraPosition = .region(
                    MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                )
            }
        }) {
            Image(systemName: "location.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(themeColor)
                .padding(10)
                .background(themeColor.opacity(0.15))
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(themeColor.opacity(0.4), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .simultaneousGesture(TapGesture().onEnded {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        })
        .padding(.trailing, 16)
    }
}
