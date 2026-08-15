import Foundation
import MapKit
import SwiftUI
import CoreLocation
import OSLog

private let shelterVMLogger = Logger(subsystem: "com.sirenua", category: "MapViewModel+ShelterSearch")

// MARK: - MapViewModel Shelter Search & Routing Extension

extension MapViewModel {

    /// Searches for nearest shelters, centers map on user's location, and computes navigation routes.
    func findNearestShelter(
        userLoc: CLLocationCoordinate2D? = nil,
        walkingSearchRadius: Double,
        drivingSearchRadius: Double,
        serverURL: String,
        presentSheet: Bool = false,
        onLocationDenied: (() -> Void)? = nil
    ) {
        guard !isRoutingToShelter else {
            shelterVMLogger.debug("Shelter search already in progress — ignoring duplicate invocation")
            return
        }

        let locManager = LocationManager.shared
        if locManager.isLocationDenied || !locManager.isLocationServicesEnabled {
            onLocationDenied?()
            return
        }

        isRoutingToShelter = true

        withAnimation {
            shelterInfoMessage = nil
            routeErrorMessage = nil
        }

        Task {
            // 1. Resolve exact live user coordinate
            let resolvedCoord: CLLocationCoordinate2D?
            if let userLoc = userLoc {
                resolvedCoord = userLoc
            } else {
                resolvedCoord = await locManager.resolveUserCoordinate(forceFresh: true)
            }

            guard let finalUserLoc = resolvedCoord else {
                await MainActor.run {
                    self.isRoutingToShelter = false
                    if locManager.isLocationDenied || !locManager.isLocationServicesEnabled {
                        onLocationDenied?()
                    } else {
                        self.routeErrorMessage = "Не вдалося визначити вашу точну геопозицію. Будь ласка, перевірте сигнал GPS та спробуйте ще раз."
                    }
                }
                return
            }

            // 2. Immediately re-center the map on the user's location when search is initiated
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.7)) {
                    self.cameraPosition = .region(
                        MKCoordinateRegion(
                            center: finalUserLoc,
                            span: MKCoordinateSpan(latitudeDelta: 0.016, longitudeDelta: 0.016)
                        )
                    )
                }
            }

            shelterVMLogger.info("Shelter search initiated at (\(finalUserLoc.latitude), \(finalUserLoc.longitude)) for mode \(self.transportType == .automobile ? "automobile" : "walking")")

            // 3. Perform search using dedicated ShelterSearchService
            let result = await ShelterSearchService.shared.searchNearbyShelters(
                userCoordinate: finalUserLoc,
                transportType: self.transportType,
                walkingRadiusKm: walkingSearchRadius,
                drivingRadiusKm: drivingSearchRadius,
                serverURL: serverURL
            )

            // 4. Update state on MainActor
            await MainActor.run {
                self.isRoutingToShelter = false

                guard let closestItem = result.closestShelter else {
                    self.allFoundShelters = []
                    self.foundShelter = nil
                    self.selectedShelter = nil
                    self.route = nil
                    self.isCalculatingRoute = false
                    self.routeErrorMessage = result.errorMessage
                    return
                }

                self.allFoundShelters = result.allFoundShelters
                self.foundShelter = closestItem
                if presentSheet {
                    self.selectedShelter = closestItem
                }
                self.route = nil
                self.routeErrorMessage = nil
                self.shelterInfoMessage = result.warningMessage
                self.isCalculatingRoute = false

                // 5. Calculate route from user to the nearest shelter
                self.calculateRoute(from: finalUserLoc, to: closestItem)
            }
        }
    }

    /// Calculates route between the source coordinate and destination shelter.
    func calculateRoute(from sourceCoordinate: CLLocationCoordinate2D, to destination: MKMapItem) {
        guard !isCalculatingRoute else { return }
        routeErrorMessage = nil
        isCalculatingRoute = true

        Task {
            let result = await ShelterRouteService.shared.calculateRoute(
                from: sourceCoordinate,
                to: destination,
                preferredTransportType: self.transportType
            )

            await MainActor.run {
                self.isCalculatingRoute = false
                self.route = result.route
                if result.actualTransportType != self.transportType {
                    self.transportType = result.actualTransportType
                }

                if let error = result.errorMessage {
                    self.routeErrorMessage = error
                }

                if let rect = result.boundingMapRect {
                    let optimalRect = ShelterRouteService.optimalCameraRect(for: rect)
                    withAnimation(.easeInOut(duration: 1.0)) {
                        self.cameraPosition = .rect(optimalRect)
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        self.cameraPosition = .region(
                            MKCoordinateRegion(
                                center: destination.placemark.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                            )
                        )
                    }
                }
            }
        }
    }
}
