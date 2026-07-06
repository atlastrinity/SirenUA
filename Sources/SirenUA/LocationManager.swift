import Foundation
import CoreLocation
import OSLog

private let locLogger = Logger(subsystem: "com.sirenua", category: "Location")

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    static let shared = LocationManager()
    
    override private init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        // Optimize power and resource usage: do not update locations continuously
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 15 // Update only if user moved 15 meters
        locLogger.info("LocationManager initialized")
    }
    
    func requestPermission() {
        locLogger.debug("Checking location permission status: \(String(describing: self.authorizationStatus))")
        switch manager.authorizationStatus {
        case .notDetermined:
            locLogger.info("Requesting when-in-use authorization")
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locLogger.info("Starting location updates")
            manager.startUpdatingLocation()
        case .denied, .restricted:
            locLogger.warning("Location access denied or restricted")
            manager.stopUpdatingLocation()
        @unknown default:
            manager.stopUpdatingLocation()
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        locLogger.info("Location authorization changed to: \(String(describing: newStatus))")
        Task { @MainActor in
            self.authorizationStatus = newStatus
            self.requestPermission()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locLogger.debug("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        Task { @MainActor in
            self.location = location
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locLogger.error("Location manager failed with error: \(error.localizedDescription)")
    }
}
