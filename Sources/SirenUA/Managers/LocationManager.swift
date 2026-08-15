import Foundation
import CoreLocation
import OSLog

private let locLogger = Logger(subsystem: "com.sirenua", category: "Location")

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    var isLocationAuthorized: Bool {
        #if os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        #else
        return authorizationStatus == .authorizedAlways
        #endif
    }
    
    var isLocationDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }
    
    var isLocationServicesEnabled: Bool {
        CLLocationManager.locationServicesEnabled()
    }
    
    private var locationContinuations: [CheckedContinuation<CLLocationCoordinate2D?, Never>] = []
    
    static let shared = LocationManager()
    
    override private init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        // Optimize power and resource usage
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 15 // Update only if user moved 15 meters
        locLogger.info("LocationManager initialized with status: \(String(describing: self.authorizationStatus))")
        
        #if os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
        #else
        if authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
        #endif
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
    
    func resolveUserCoordinate(timeoutSeconds: Double = 3.5) async -> CLLocationCoordinate2D? {
        guard CLLocationManager.locationServicesEnabled() else {
            locLogger.warning("Location services disabled system-wide")
            return nil
        }
        
        if isLocationDenied {
            locLogger.warning("Location access denied or restricted by user")
            return nil
        }

        if authorizationStatus == .notDetermined {
            requestPermission()
        }

        if let loc = location, abs(loc.timestamp.timeIntervalSinceNow) < 60 {
            locLogger.debug("Using cached recent location: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
            return loc.coordinate
        }

        manager.startUpdatingLocation()

        return await withCheckedContinuation { continuation in
            locationContinuations.append(continuation)

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                self.flushContinuations(with: self.location?.coordinate)
            }
        }
    }
    
    private func flushContinuations(with coordinate: CLLocationCoordinate2D?) {
        guard !locationContinuations.isEmpty else { return }
        let continuations = locationContinuations
        locationContinuations.removeAll()
        for cont in continuations {
            cont.resume(returning: coordinate)
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        locLogger.info("Location authorization changed to: \(String(describing: newStatus))")
        Task { @MainActor in
            self.authorizationStatus = newStatus
            self.requestPermission()
            if self.isLocationDenied {
                self.flushContinuations(with: nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locLogger.debug("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        Task { @MainActor in
            self.location = location
            self.flushContinuations(with: location.coordinate)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locLogger.error("Location manager failed with error: \(error.localizedDescription)")
        Task { @MainActor in
            self.flushContinuations(with: self.location?.coordinate)
        }
    }
}
