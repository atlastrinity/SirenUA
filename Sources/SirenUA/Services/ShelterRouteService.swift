import Foundation
import MapKit
import CoreLocation
import OSLog

private let routeLogger = Logger(subsystem: "com.sirenua", category: "ShelterRouteService")

// MARK: - Route Calculation Result

struct ShelterRouteResult {
    let route: MKRoute?
    let actualTransportType: MKDirectionsTransportType
    let boundingMapRect: MKMapRect?
    let errorMessage: String?
}

// MARK: - Shelter Route Service

final class ShelterRouteService {
    static let shared = ShelterRouteService()

    private init() {}

    /// Calculates a route between user's coordinates and a shelter destination.
    func calculateRoute(
        from sourceCoordinate: CLLocationCoordinate2D,
        to destination: MKMapItem,
        preferredTransportType: MKDirectionsTransportType
    ) async -> ShelterRouteResult {
        let request = MKDirections.Request()
        let sourcePlacemark = MKPlacemark(coordinate: sourceCoordinate)
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = destination
        request.transportType = preferredTransportType

        routeLogger.info("Calculating route for mode \(preferredTransportType == .automobile ? "automobile" : "walking")...")

        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            guard let primaryRoute = response.routes.first else {
                return ShelterRouteResult(
                    route: nil,
                    actualTransportType: preferredTransportType,
                    boundingMapRect: nil,
                    errorMessage: "Маршрут не знайдено"
                )
            }

            let rect = primaryRoute.polyline.boundingMapRect
            return ShelterRouteResult(
                route: primaryRoute,
                actualTransportType: preferredTransportType,
                boundingMapRect: rect,
                errorMessage: nil
            )
        } catch {
            routeLogger.warning("Route calculation failed for \(preferredTransportType == .automobile ? "automobile" : "walking"): \(error.localizedDescription)")

            // If walking failed, attempt automobile as fallback calculation
            if preferredTransportType == .walking {
                let fallbackRequest = MKDirections.Request()
                fallbackRequest.source = request.source
                fallbackRequest.destination = destination
                fallbackRequest.transportType = .automobile

                if let fallbackResponse = try? await MKDirections(request: fallbackRequest).calculate(),
                   let fallbackRoute = fallbackResponse.routes.first {
                    routeLogger.info("Automobile fallback route calculated successfully")
                    return ShelterRouteResult(
                        route: fallbackRoute,
                        actualTransportType: .automobile,
                        boundingMapRect: fallbackRoute.polyline.boundingMapRect,
                        errorMessage: nil
                    )
                }
            }

            return ShelterRouteResult(
                route: nil,
                actualTransportType: preferredTransportType,
                boundingMapRect: nil,
                errorMessage: "Маршрут недоступний. Спробуйте інший режим або укриття."
            )
        }
    }

    /// Computes an optimal padded map rect for framing both source and destination nicely.
    static func optimalCameraRect(for polylineRect: MKMapRect) -> MKMapRect {
        let dx = max(polylineRect.size.width * 0.35, 600.0)
        let dy = max(polylineRect.size.height * 0.45, 800.0)
        return polylineRect.insetBy(dx: -dx, dy: -dy)
    }
}
