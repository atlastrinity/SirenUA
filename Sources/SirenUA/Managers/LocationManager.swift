import Foundation
import CoreLocation
import OSLog

private let locLogger = Logger(subsystem: "com.sirenua", category: "Location")

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var hasLiveLocationFix: Bool = false
    
    var isLocationInitialized: Bool {
        hasLiveLocationFix && location != nil
    }
    
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
    
    private var lastKnownLocation: CLLocation?
    private var locationContinuations: [CheckedContinuation<CLLocationCoordinate2D?, Never>] = []
    private var authContinuations: [CheckedContinuation<Bool, Never>] = []
    
    static let shared = LocationManager()
    
    override private init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        // Optimize accuracy and response time
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10 // Update if user moved 10 meters
        
        // 1. Restore persisted location from shared UserDefaults on cold start for initial fallback only
        if let defaults = UserDefaults(suiteName: "group.com.sirenua.shared") {
            let lat = defaults.double(forKey: "location_last_known_lat")
            let lon = defaults.double(forKey: "location_last_known_lon")
            let ts = defaults.double(forKey: "location_last_known_ts")
            if lat != 0.0 && lon != 0.0 {
                let date = ts > 0 ? Date(timeIntervalSince1970: ts) : Date.distantPast
                let cachedLoc = CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    altitude: 0,
                    horizontalAccuracy: 100,
                    verticalAccuracy: 100,
                    timestamp: date
                )
                self.lastKnownLocation = cachedLoc
                self.location = cachedLoc
                self.hasLiveLocationFix = false
                locLogger.info("Restored persisted fallback location: \(lat), \(lon)")
            }
        }
        
        // 2. Adopt system manager.location if available as fallback
        if let sysLoc = manager.location {
            self.lastKnownLocation = sysLoc
            if self.location == nil {
                self.location = sysLoc
            }
            locLogger.info("Adopted system manager.location fallback: \(sysLoc.coordinate.latitude), \(sysLoc.coordinate.longitude)")
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
    
    func requestPermissionAsync(timeoutSeconds: Double = 10.0) async -> Bool {
        if isLocationAuthorized { return true }
        if isLocationDenied { return false }
        
        requestPermission()
        
        return await withCheckedContinuation { continuation in
            authContinuations.append(continuation)
            
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                self.flushAuthContinuations(with: self.isLocationAuthorized)
            }
        }
    }
    
    func requestFreshLocation() {
        guard isLocationAuthorized else { return }
        manager.requestLocation()
        manager.startUpdatingLocation()
    }
    
    /// Resolves the user's verified live coordinates, actively ensuring a fresh GPS fix is acquired before returning.
    func resolveUserCoordinate(timeoutSeconds: Double = 6.0, forceFresh: Bool = false) async -> CLLocationCoordinate2D? {
        guard CLLocationManager.locationServicesEnabled() else {
            locLogger.warning("Location services disabled system-wide")
            return location?.coordinate ?? lastKnownLocation?.coordinate
        }
        
        if isLocationDenied {
            locLogger.warning("Location access denied or restricted by user")
            return nil
        }

        if authorizationStatus == .notDetermined {
            let granted = await requestPermissionAsync(timeoutSeconds: 8.0)
            if !granted {
                locLogger.warning("Location permission not granted by user")
                return nil
            }
        }

        // If we already have a verified live GPS fix in the current session and it is fresh (< 60s), return immediately
        if !forceFresh && hasLiveLocationFix, let loc = location,
           abs(loc.timestamp.timeIntervalSinceNow) < 60,
           loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= 150 {
            locLogger.debug("Using fresh live session location: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
            return loc.coordinate
        }

        // Request live one-shot GPS update
        locLogger.info("Requesting fresh GPS fix for location resolution...")
        manager.requestLocation()
        manager.startUpdatingLocation()

        return await withCheckedContinuation { continuation in
            locationContinuations.append(continuation)

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                // On timeout: if we got a live fix during sleep, return it; otherwise return best fallback
                let fallback = self.location?.coordinate ?? self.lastKnownLocation?.coordinate ?? self.manager.location?.coordinate
                if self.hasLiveLocationFix {
                    locLogger.debug("Resolved live coordinate before timeout: \(String(describing: fallback))")
                } else {
                    locLogger.warning("Location resolution timeout (\(timeoutSeconds)s). Returning fallback coordinate: \(String(describing: fallback))")
                }
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
    
    private func flushAuthContinuations(with granted: Bool) {
        guard !authContinuations.isEmpty else { return }
        let continuations = authContinuations
        authContinuations.removeAll()
        for cont in continuations {
            cont.resume(returning: granted)
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        locLogger.info("Location authorization changed to: \(String(describing: newStatus))")
        Task { @MainActor in
            self.authorizationStatus = newStatus
            let granted = self.isLocationAuthorized
            self.flushAuthContinuations(with: granted)
            
            if granted {
                manager.startUpdatingLocation()
                manager.requestLocation()
            } else if self.isLocationDenied {
                self.flushContinuations(with: nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        locLogger.debug("Live GPS location updated: \(location.coordinate.latitude), \(location.coordinate.longitude), accuracy: \(location.horizontalAccuracy)m")
        Task { @MainActor in
            self.location = location
            self.lastKnownLocation = location
            self.hasLiveLocationFix = true
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
            let best = self.location?.coordinate ?? self.lastKnownLocation?.coordinate ?? self.manager.location?.coordinate
            self.flushContinuations(with: best)
        }
    }
}
