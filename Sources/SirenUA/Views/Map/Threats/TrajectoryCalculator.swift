import Foundation
import CoreLocation

// MARK: - Trajectory Flow Arrow Data

public struct TrajectoryFlowArrow {
    public let coordinate: CLLocationCoordinate2D
    public let angle: Double
    public let opacity: Double

    public init(coordinate: CLLocationCoordinate2D, angle: Double, opacity: Double) {
        self.coordinate = coordinate
        self.angle = angle
        self.opacity = opacity
    }
}

// MARK: - Trajectory Path Data

public struct TrajectoryPath {
    public let fullPoints: [CLLocationCoordinate2D]
    public let flowArrows: [TrajectoryFlowArrow]
    public let lastCheckpointCoordinate: CLLocationCoordinate2D
    public let lastCheckpointAngle: Double
    public let carrierApproachPoints: [CLLocationCoordinate2D]?
    public let carrierOriginName: String?
    public let launchSectorName: String?

    public init(
        fullPoints: [CLLocationCoordinate2D],
        flowArrows: [TrajectoryFlowArrow],
        lastCheckpointCoordinate: CLLocationCoordinate2D,
        lastCheckpointAngle: Double,
        carrierApproachPoints: [CLLocationCoordinate2D]? = nil,
        carrierOriginName: String? = nil,
        launchSectorName: String? = nil
    ) {
        self.fullPoints = fullPoints
        self.flowArrows = flowArrows
        self.lastCheckpointCoordinate = lastCheckpointCoordinate
        self.lastCheckpointAngle = lastCheckpointAngle
        self.carrierApproachPoints = carrierApproachPoints
        self.carrierOriginName = carrierOriginName
        self.launchSectorName = launchSectorName
    }
}

// MARK: - Trajectory Calculator

public func calculateTrajectory(
    target: CLLocationCoordinate2D,
    threatType: String?,
    customOrigin: CLLocationCoordinate2D? = nil,
    carrierOrigin: CLLocationCoordinate2D? = nil,
    launchSector: CLLocationCoordinate2D? = nil,
    carrierOriginName: String? = nil,
    launchSectorName: String? = nil
) -> TrajectoryPath {
    let curvature: Double
    let cycles: Double
    let waveAmplitude: Double
    
    switch threatType {
    case "shahed":
        curvature = -0.22 // Base aerodynamic arc
        cycles = 3.5      // 3.5 weaving S-curves (змійка)
        waveAmplitude = 0.055 // Realistic lateral evasion amplitude
    case "cruise_missile", "tu95":
        curvature = 0.20
        cycles = 2.5      // 2.5 tactical waypoint weaves
        waveAmplitude = 0.045
    case "tu22m3":
        // Ту-22М3: надзвукова Х-22/Х-32 — майже пряма балістична дуга, мінімальне відхилення
        curvature = -0.18
        cycles = 1.2      // Supersonic — minor terminal correction only
        waveAmplitude = 0.015
    case "ballistic", "iskander":
        curvature = -0.15
        cycles = 1.5      // Minor terminal trajectory wobble
        waveAmplitude = 0.025
    case "kab":
        curvature = 0.15
        cycles = 2.0      // Wind drift glide weaving
        waveAmplitude = 0.035
    default:
        curvature = 0.20
        cycles = 3.0
        waveAmplitude = 0.040
    }
    
    let startLat: Double
    let startLon: Double

    // Calculate distance between customOrigin and target to detect city-center fallbacks
    let originDistanceKm: Double = {
        guard let origin = customOrigin else { return 0 }
        let dLat = (origin.latitude - target.latitude) * 111.0
        let dLon = (origin.longitude - target.longitude) * 111.0 * cos(target.latitude * .pi / 180.0)
        return sqrt(dLat * dLat + dLon * dLon)
    }()

    // Regional capital centroids list — used to identify regional transit fallbacks
    let regionalCenters: [(Double, Double)] = [
        (49.2331, 28.4682), (50.7412, 25.3201), (48.4647, 35.0462), (48.0159, 37.8028),
        (50.2547, 28.6587), (48.6208, 22.2879), (47.8388, 35.1396), (48.9226, 24.7111),
        (50.0500, 30.1500), (50.4501, 30.5234), (48.5079, 32.2623), (48.5740, 39.3078),
        (49.8397, 24.0297), (46.9750, 31.9946), (46.4825, 30.7233), (49.5883, 34.5514),
        (50.6199, 26.2516), (50.9077, 34.7981), (49.5535, 25.5948), (49.9935, 36.2304),
        (46.6354, 32.6169), (49.4230, 26.9871), (49.4444, 32.0598), (48.2915, 25.9352),
        (51.4982, 31.2893)
    ]

    let isRegionalCentroid: Bool = {
        guard let origin = customOrigin else { return false }
        for (cLat, cLon) in regionalCenters {
            let dLat = (origin.latitude - cLat) * 111.0
            let dLon = (origin.longitude - cLon) * 111.0 * cos(cLat * .pi / 180.0)
            if sqrt(dLat * dLat + dLon * dLon) < 25.0 {
                return true
            }
        }
        return false
    }()

    if let origin = customOrigin, originDistanceKm > 20.0, !isRegionalCentroid {
        // Real external launch site (e.g. Shaykovka, Mozdok, Primorsko-Akhtarsk)
        startLat = origin.latitude
        startLon = origin.longitude
    } else if let origin = customOrigin, originDistanceKm > 20.0, isRegionalCentroid {
        // Transit origin: origin is a regional centroid (e.g. Dnipro city center).
        // Extrapolate backwards through the transit centroid to launch corridor / border!
        let dLat = target.latitude - origin.latitude
        let dLon = target.longitude - origin.longitude
        let scale = max(1.5, 160.0 / max(10.0, originDistanceKm))
        startLat = origin.latitude - dLat * scale
        startLon = origin.longitude - dLon * scale
    } else {
        // Otherwise, extrapolate origin back to state border / sea entry corridor
        switch threatType {
        case "shahed":
            if target.latitude < 47.9 {
                // Southern targets (Odesa, Mykolaiv, Kherson, Zaporizhzhia): project to Black Sea / Crimea border
                startLat = min(45.8, target.latitude - 1.2)
                startLon = max(30.5, target.longitude + 1.2)
            } else if target.longitude > 34.0 {
                // Eastern targets (Kharkiv, Sumy, Poltava, Dnipro, Luhansk, Donetsk): project to Belgorod / Kursk border
                startLat = max(50.4, target.latitude + 0.6)
                startLon = max(36.4, target.longitude + 0.8)
            } else {
                // Central / Northern / Western targets (Kirovohrad, Cherkasy, Kyiv, Vinnytsia, Zhytomyr): project from East / North-East ingress
                startLat = target.latitude + 0.8
                startLon = target.longitude + 1.8
            }
        case "cruise_missile", "tu95":
            // Cruise missile / Tu-95: project to Caspian Sea / East border
            startLat = max(48.5, target.latitude + 0.8)
            startLon = max(39.2, target.longitude + 3.2)
        case "tu22m3":
            // Ту-22М3: Шайковка (54.22, 34.36) або Моздок (43.78, 44.60)
            if target.latitude > 48.5 {
                startLat = 54.22  // Shaykovka
                startLon = 34.36
            } else {
                startLat = 43.78  // Mozdok
                startLon = 44.60
            }
        case "ballistic", "iskander":
            // Ballistic: project to Belgorod / Kursk / Savasleyka North-East border
            startLat = max(50.5, target.latitude + 0.8)
            startLon = max(36.5, target.longitude + 0.6)
        case "kab":
            // KAB: project to Frontline / Border
            startLat = target.latitude + 0.4
            startLon = target.longitude + 0.5
        default:
            startLat = max(50.5, target.latitude + 0.8)
            startLon = max(35.5, target.longitude + 1.2)
        }
    }
    
    let dLat = target.latitude - startLat
    let dLon = target.longitude - startLon
    let distance = max(0.1, sqrt(dLat * dLat + dLon * dLon))
    
    // True perpendicular normal vector (-dLon, dLat)
    let normalLat = -dLon / distance
    let normalLon = dLat / distance
    
    let midLat = (startLat + target.latitude) / 2.0
    let midLon = (startLon + target.longitude) / 2.0
    
    // Aerodynamic control point offset along true perpendicular vector
    let controlLat = midLat + normalLat * (distance * curvature)
    let controlLon = midLon + normalLon * (distance * curvature)
    
    var fullPoints: [CLLocationCoordinate2D] = []
    let steps = 48 // 48 ultra-smooth interpolated points
    for i in 0...steps {
        let t = Double(i) / Double(steps)
        let invT = 1.0 - t
        
        let baseLat = invT * invT * startLat + 2.0 * invT * t * controlLat + t * t * target.latitude
        let baseLon = invT * invT * startLon + 2.0 * invT * t * controlLon + t * t * target.longitude
        
        let tangentLat = 2.0 * invT * (controlLat - startLat) + 2.0 * t * (target.latitude - controlLat)
        let tangentLon = 2.0 * invT * (controlLon - startLon) + 2.0 * t * (target.longitude - controlLon)
        let tLen = max(0.0001, sqrt(tangentLat * tangentLat + tangentLon * tangentLon))
        
        let localPerpLat = -tangentLon / tLen
        let localPerpLon = tangentLat / tLen
        
        let envelope = sin(t * .pi)
        let snakeOffset = sin(t * .pi * 2.0 * cycles) * envelope * (distance * waveAmplitude)
        
        let finalLat = baseLat + localPerpLat * snakeOffset
        let finalLon = baseLon + localPerpLon * snakeOffset
        
        fullPoints.append(CLLocationCoordinate2D(latitude: finalLat, longitude: finalLon))
    }

    // Directional flow arrows at ~25%, ~50%, and ~75% along trajectory
    var flowArrows: [TrajectoryFlowArrow] = []
    let arrowStepIndices = [12, 24, 36]
    for stepIdx in arrowStepIndices {
        let ap1 = fullPoints[stepIdx]
        let ap2 = fullPoints[stepIdx + 1]
        let aDeltaLat = ap2.latitude - ap1.latitude
        let aDeltaLon = ap2.longitude - ap1.longitude
        let aAngleRad = atan2(aDeltaLon, aDeltaLat)
        let aAngleDeg = aAngleRad * 180.0 / .pi
        let progress = Double(stepIdx) / Double(steps)
        let arrowOpacity = 0.50 + (progress * 0.50)
        flowArrows.append(TrajectoryFlowArrow(coordinate: ap1, angle: aAngleDeg, opacity: arrowOpacity))
    }

    // Last telemetry checkpoint at ~80% along the trajectory
    let checkpointIdx = 38
    let p1 = fullPoints[checkpointIdx]
    let p2 = fullPoints[checkpointIdx + 1]

    let deltaLat = p2.latitude - p1.latitude
    let deltaLon = p2.longitude - p1.longitude
    let angleRad = atan2(deltaLon, deltaLat)
    let angleDeg = angleRad * 180.0 / .pi

    // Calculate Carrier Ingress Approach (Airbase -> Launch Sector)
    var carrierApproachPoints: [CLLocationCoordinate2D]? = nil
    if let carrier = carrierOrigin {
        var approach: [CLLocationCoordinate2D] = []
        let appSteps = 24
        let appMidLat = (carrier.latitude + startLat) / 2.0
        let appMidLon = (carrier.longitude + startLon) / 2.0
        let dLatApp = (startLat - carrier.latitude) * 111.0
        let dLonApp = (startLon - carrier.longitude) * 111.0 * cos(carrier.latitude * .pi / 180.0)
        let appDist = max(0.1, sqrt(dLatApp * dLatApp + dLonApp * dLonApp))
        let appCurvatureScale = min(0.25, max(0.05, appDist * 0.0003))
        
        let appNormalLat = -(startLon - carrier.longitude) / max(0.01, sqrt(pow(startLat - carrier.latitude, 2) + pow(startLon - carrier.longitude, 2)))
        let appNormalLon = (startLat - carrier.latitude) / max(0.01, sqrt(pow(startLat - carrier.latitude, 2) + pow(startLon - carrier.longitude, 2)))
        let appControlLat = appMidLat + appNormalLat * appCurvatureScale
        let appControlLon = appMidLon + appNormalLon * appCurvatureScale

        for i in 0...appSteps {
            let t = Double(i) / Double(appSteps)
            let invT = 1.0 - t
            let lat = invT * invT * carrier.latitude + 2.0 * invT * t * appControlLat + t * t * startLat
            let lon = invT * invT * carrier.longitude + 2.0 * invT * t * appControlLon + t * t * startLon
            approach.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        carrierApproachPoints = approach
    }

    return TrajectoryPath(
        fullPoints: fullPoints,
        flowArrows: flowArrows,
        lastCheckpointCoordinate: p1,
        lastCheckpointAngle: angleDeg,
        carrierApproachPoints: carrierApproachPoints,
        carrierOriginName: carrierOriginName,
        launchSectorName: launchSectorName
    )
}
