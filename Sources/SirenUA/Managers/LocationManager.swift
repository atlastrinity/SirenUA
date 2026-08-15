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
        // Optimize accuracy and response time
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10 // Update if user moved 10 meters
        
        // 1. Restore persisted location from shared UserDefaults on cold start
        if let defaults = UserDefaults(suiteName: "group.com.sirenua.shared") {
            let lat = defaults.double(forKey: "location_last_known_lat")
            let lon = defaults.double(forKey: "location_last_known_lon")
            let ts = defaults.double(forKey: "location_last_known_ts")
            if lat != 0.0 && lon != 0.0 {
                let date = ts > 0 ? Date(timeIntervalSince1970: ts) : Date()
                self.location = CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    altitude: 0,
                    horizontalAccuracy: 100,
                    verticalAccuracy: 100,
                    timestamp: date
                )
                locLogger.info("Restored persisted location: \(lat), \(lon)")
            }
        }
        
        // 2. Adopt system manager.location immediately if available
        if let sysLoc = manager.location {
            self.location = sysLoc
            locLogger.info("Adopted system manager.location: \(sysLoc.coordinate.latitude), \(sysLoc.coordinate.longitude)")
        }
        
        locLogger.info("LocationManager initialized with status: \(String(describing: self.authorizationStatus))")
        
        #if os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            manager.requestLocation()
        }
        #else
        if authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            manager.requestLocation()
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
            manager.requestLocation()
        case .denied, .restricted:
            locLogger.warning("Location access denied or restricted")
            manager.stopUpdatingLocation()
        @unknown default:
            manager.stopUpdatingLocation()
        }
    }
    
    func requestFreshLocation() {
        guard isLocationAuthorized else { return }
        manager.requestLocation()
        manager.startUpdatingLocation()
    }
    
    func resolveUserCoordinate(timeoutSeconds: Double = 4.5) async -> CLLocationCoordinate2D? {
        guard CLLocationManager.locationServicesEnabled() else {
            locLogger.warning("Location services disabled system-wide")
            return location?.coordinate
        }
        
        if isLocationDenied {
            locLogger.warning("Location access denied or restricted by user")
            return nil
        }

        if authorizationStatus == .notDetermined {
            requestPermission()
        }

        // 1. If we have a recent location (< 180s), return immediately
        if let loc = location, abs(loc.timestamp.timeIntervalSinceNow) < 180 {
            locLogger.debug("Using cached recent location: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
            return loc.coordinate
        }
        
        // 2. If system manager.location is available and recent, adopt it
        if let sysLoc = manager.location, abs(sysLoc.timestamp.timeIntervalSinceNow) < 300 {
            self.location = sysLoc
            locLogger.debug("Using system manager.location: \(sysLoc.coordinate.latitude), \(sysLoc.coordinate.longitude)")
            return sysLoc.coordinate
        }

        // 3. Request immediate one-shot GPS update
        manager.requestLocation()
        manager.startUpdatingLocation()

        return await withCheckedContinuation { continuation in
            locationContinuations.append(continuation)

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                // On timeout, return best available coordinate rather than nil
                let fallback = self.location?.coordinate ?? self.manager.location?.coordinate
                self.flushContinuations(with: fallback)
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
            if let defaults = UserDefaults(suiteName: "group.com.sirenua.shared") {
                defaults.set(location.coordinate.latitude, forKey: "location_last_known_lat")
                defaults.set(location.coordinate.longitude, forKey: "location_last_known_lon")
                defaults.set(location.timestamp.timeIntervalSince1970, forKey: "location_last_known_ts")
            }
            self.flushContinuations(with: location.coordinate)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locLogger.warning("Location manager error or timeout: \(error.localizedDescription)")
        Task { @MainActor in
            let best = self.location?.coordinate ?? self.manager.location?.coordinate
            self.flushContinuations(with: best)
        }
    }
}
