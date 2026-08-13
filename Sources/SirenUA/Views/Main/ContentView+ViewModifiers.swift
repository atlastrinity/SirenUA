import SwiftUI

struct ContentViewTabHandlers: ViewModifier {
    @ObservedObject var mapViewModel: MapViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: mapViewModel.selectedTab) { _, newValue in
                switch newValue {
                case 0:
                    mapViewModel.showHistory = false
                    mapViewModel.showActiveAlerts = false
                case 1:
                    mapViewModel.showActiveAlerts = false
                    mapViewModel.showHistory = true
                case 2:
                    mapViewModel.showHistory = false
                    mapViewModel.showActiveAlerts = true
                case 3:
                    mapViewModel.showHistory = false
                    mapViewModel.showActiveAlerts = false
                    mapViewModel.activeSheet = .settings
                default:
                    break
                }
            }
            .onChange(of: mapViewModel.showHistory) { _, isShowing in
                if !isShowing && mapViewModel.selectedTab == 1 {
                    mapViewModel.selectedTab = 0
                }
            }
            .onChange(of: mapViewModel.showActiveAlerts) { _, isShowing in
                if !isShowing && mapViewModel.selectedTab == 2 {
                    mapViewModel.selectedTab = 0
                }
            }
            .onChange(of: mapViewModel.activeSheet) { _, activeSheet in
                if activeSheet == nil && mapViewModel.selectedTab == 3 {
                    mapViewModel.selectedTab = 0
                }
            }
    }
}

struct ContentViewMapStateHandlers: ViewModifier {
    @ObservedObject var viewModel: AlertViewModelV3
    @ObservedObject var mapViewModel: MapViewModel
    @ObservedObject var geoManager: GeoJSONManager
    @Environment(\.scenePhase) private var scenePhase
    @Binding var onboardingCompleted: Bool

    @State private var lastActiveFootprint: String = ""

    private func triggerMapCenter(animated: Bool = false) {
        mapViewModel.centerMapOnAlerts(
            alerts: viewModel.alerts,
            isPremium: viewModel.isPremium,
            lastAlertedRegionName: viewModel.lastAlertedRegionName,
            regions: geoManager.regions,
            animated: animated
        )
    }

    private func triggerMapCenterIfNeeded(animated: Bool = false) {
        let footprint = viewModel.alerts
            .filter { $0.isActive || $0.threatLevel != nil }
            .map { "\($0.id):\($0.isActive):\($0.threatLevel ?? "")" }
            .joined(separator: "|")
        if footprint != lastActiveFootprint {
            lastActiveFootprint = footprint
            triggerMapCenter(animated: animated)
        }
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: onboardingCompleted) { _, newValue in
                if newValue {
                    triggerMapCenter()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await viewModel.fetchThreatState()
                        triggerMapCenter(animated: true)
                    }
                }
            }
            .onChange(of: viewModel.alerts) { _, _ in
                triggerMapCenterIfNeeded(animated: true)
            }
            .onChange(of: geoManager.isLoaded) { _, newValue in
                if newValue {
                    triggerMapCenter()
                }
            }
    }
}

extension View {
    func tabHandlers(mapViewModel: MapViewModel) -> some View {
        modifier(ContentViewTabHandlers(mapViewModel: mapViewModel))
    }

    func mapStateHandlers(
        viewModel: AlertViewModelV3,
        mapViewModel: MapViewModel,
        geoManager: GeoJSONManager,
        onboardingCompleted: Binding<Bool>
    ) -> some View {
        modifier(ContentViewMapStateHandlers(
            viewModel: viewModel,
            mapViewModel: mapViewModel,
            geoManager: geoManager,
            onboardingCompleted: onboardingCompleted
        ))
    }
}
