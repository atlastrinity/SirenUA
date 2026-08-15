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

    // MARK: Map Floating Controls (Локація та Концентрація Областей)

    var mapFloatingControls: some View {
        HStack {
            // Ліва прозора кнопка: Наведення на власну локацію
            Button(action: {
                if locationManager.isLocationDenied || !locationManager.isLocationServicesEnabled {
                    showLocationPermissionAlert = true
                } else if let loc = locationManager.location {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        mapViewModel.cameraPosition = .region(
                            MKCoordinateRegion(
                                center: loc.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                            )
                        )
                    }
                } else {
                    locationManager.requestPermission()
                    Task {
                        if let coord = await locationManager.resolveUserCoordinate() {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                mapViewModel.cameraPosition = .region(
                                    MKCoordinateRegion(
                                        center: coord,
                                        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                                    )
                                )
                            }
                        }
                    }
                }
            }) {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.cyan)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .background(Color.cyan.opacity(0.15))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
            }
            .simultaneousGesture(TapGesture().onEnded {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            })

            Spacer()

            // Права прозора кнопка: Концентрація обраних/активних областей в рамки екрану
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    mapViewModel.centerMapOnAlerts(
                        alerts: viewModel.alerts,
                        isPremium: viewModel.isPremium,
                        lastAlertedRegionName: viewModel.lastAlertedRegionName,
                        regions: geoManager.regions,
                        animated: true
                    )
                }
            }) {
                Image(systemName: "scope")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.yellow)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.yellow.opacity(0.4), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
            }
            .simultaneousGesture(TapGesture().onEnded {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            })
        }
        .padding(.horizontal, 18)
    }
}
