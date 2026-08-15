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
    case ThreatConstants.shahed:
        curvature = -0.20 // Base aerodynamic arc
        cycles = 3.5      // 3.5 weaving S-curves (змійка)
        waveAmplitude = 0.045 // Realistic lateral evasion amplitude
    case ThreatConstants.cruiseMissile, ThreatConstants.tu95:
        curvature = 0.18
        cycles = 2.5      // 2.5 tactical waypoint weaves
        waveAmplitude = 0.038
    case ThreatConstants.tu22m3:
        // Ту-22М3: надзвукова Х-22/Х-32 — майже пряма балістична дуга, мінімальне відхилення
        curvature = -0.15
        cycles = 1.0      // Supersonic — minor terminal correction only
        waveAmplitude = 0.012
    case ThreatConstants.ballistic, ThreatConstants.iskander, ThreatConstants.zircon:
        curvature = -0.12
        cycles = 1.2      // Minor terminal trajectory wobble
        waveAmplitude = 0.020
    case ThreatConstants.kab:
        curvature = 0.12
        cycles = 1.8      // Wind drift glide weaving
        waveAmplitude = 0.028
    case ThreatConstants.artillery, ThreatConstants.mlrs:
        curvature = 0.05
        cycles = 1.0
        waveAmplitude = 0.010
    case ThreatConstants.fpv, ThreatConstants.recon, ThreatConstants.reconUAV:
        curvature = 0.10
        cycles = 2.2
        waveAmplitude = 0.025
    default:
        curvature = 0.18
        cycles = 2.8
        waveAmplitude = 0.035
    }
    
    // Regional capital centroids list — used to identify regional transit waypoints
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

    let originDistanceKm: Double = {
        guard let origin = customOrigin else { return 0 }
        let dLat = (origin.latitude - target.latitude) * 111.0
        let dLon = (origin.longitude - target.longitude) * 111.0 * cos(target.latitude * .pi / 180.0)
        return sqrt(dLat * dLat + dLon * dLon)
    }()

    let startCoord: CLLocationCoordinate2D
    var transitWaypoint: CLLocationCoordinate2D? = nil

    // 1. PRIORITY 1: Explicit Launch Sector provided (e.g. Азовське море, Чорне море, Чауда, Курськ, Бєлгород)
    if let sector = launchSector {
        startCoord = sector
        if let origin = customOrigin {
            let dLatSector = (sector.latitude - origin.latitude) * 111.0
            let dLonSector = (sector.longitude - origin.longitude) * 111.0 * cos(origin.latitude * .pi / 180.0)
            let distSectorToOrigin = sqrt(dLatSector * dLatSector + dLonSector * dLonSector)
            
            // If customOrigin is a distinct transit waypoint (e.g. Dnipropetrovsk when sector is Azov Sea)
            if distSectorToOrigin > 35.0 && originDistanceKm > 35.0 {
                transitWaypoint = origin
            }
        }
    }
    // 2. PRIORITY 2: Custom Origin provided without explicit Launch Sector
    else if let origin = customOrigin, originDistanceKm > 20.0 {
        if isRegionalCentroid {
            // Origin is a regional transit centroid (e.g. Дніпропетровська область)
            transitWaypoint = origin
            // Correlate natural entrance corridor sector based on transit location and target
            if origin.longitude > 34.5 && origin.latitude < 48.8 {
                // Dnipro / Zaporizhzhia transit -> Ingress from Azov Sea (46.20, 36.50)
                startCoord = CLLocationCoordinate2D(latitude: 46.20, longitude: 36.50)
            } else if origin.latitude > 50.5 && origin.longitude < 34.5 {
                // Sumy / Chernihiv transit -> Ingress from Kursk / Bryansk (51.70, 35.50)
                startCoord = CLLocationCoordinate2D(latitude: 51.70, longitude: 35.50)
            } else if origin.longitude > 35.5 && origin.latitude > 49.5 {
                // Kharkiv transit -> Ingress from Belgorod (50.60, 36.58)
                startCoord = CLLocationCoordinate2D(latitude: 50.60, longitude: 36.58)
            } else if origin.latitude < 47.0 {
                // Kherson / Odesa / Mykolaiv transit -> Ingress from Black Sea (44.50, 32.00)
                startCoord = CLLocationCoordinate2D(latitude: 44.50, longitude: 32.00)
            } else {
                // Fallback: extrapolate backward through transit point
                let dLat = target.latitude - origin.latitude
                let dLon = target.longitude - origin.longitude
                let scale = max(1.5, 160.0 / max(10.0, originDistanceKm))
                startCoord = CLLocationCoordinate2D(
                    latitude: origin.latitude - dLat * scale,
                    longitude: origin.longitude - dLon * scale
                )
            }
        } else {
            // Real external launch site (e.g. Shaykovka, Mozdok, Primorsko-Akhtarsk)
            startCoord = origin
        }
    }
    // 3. PRIORITY 3: Strategic weapon default launch sectors based on threat type and target
    else {
        let sLat: Double
        let sLon: Double
        switch threatType {
        case "shahed":
            if target.latitude < 47.9 {
                // Southern targets (Odesa, Mykolaiv, Kherson, Zaporizhzhia): Black Sea / Chauda / Azov
                if target.longitude > 34.0 {
                    sLat = 46.20 // Azov Sea
                    sLon = 36.50
                } else {
                    sLat = 44.50 // Black Sea
                    sLon = 32.00
                }
            } else if target.longitude > 34.0 {
                // Eastern targets (Kharkiv, Sumy, Poltava, Dnipro): Belgorod / Kursk
                sLat = max(50.4, target.latitude + 0.6)
                sLon = max(36.4, target.longitude + 0.8)
            } else {
                // Central / Northern / Western targets: Kursk / Orel ingress
                sLat = target.latitude + 0.8
                sLon = target.longitude + 1.8
            }
        case "cruise_missile", "tu95":
            // Cruise missile / Tu-95: Caspian Sea / Engels
            sLat = max(48.5, target.latitude + 0.8)
            sLon = max(39.2, target.longitude + 3.2)
        case "tu22m3":
            // Ту-22М3: Шайковка (54.22, 34.36) або Моздок (43.78, 44.60)
            if target.latitude > 48.5 {
                sLat = 54.22  // Shaykovka
                sLon = 34.36
            } else {
                sLat = 43.78  // Mozdok
                sLon = 44.60
            }
        case "ballistic", "iskander":
            // Ballistic: Belgorod / Kursk / Savasleyka / Crimea
            if target.latitude < 47.5 {
                sLat = 45.40 // Crimea Tarkhankut / Dzhankoy
                sLon = 34.30
            } else {
                sLat = max(50.5, target.latitude + 0.8)
                sLon = max(36.5, target.longitude + 0.6)
            }
        case "kab":
            // KAB: Frontline / Border
            sLat = target.latitude + 0.4
            sLon = target.longitude + 0.5
        default:
            sLat = max(50.5, target.latitude + 0.8)
            sLon = max(35.5, target.longitude + 1.2)
        }
        startCoord = CLLocationCoordinate2D(latitude: sLat, longitude: sLon)
    }

    // MARK: - Aerodynamic Smooth Continuous Spline Generation
    var rawPoints: [CLLocationCoordinate2D] = []

    if let waypoint = transitWaypoint {
        // Multi-segment with aerodynamic turn arc (fillet curve around waypoint)
        rawPoints = generateMultiWaypointSmoothSpline(
            start: startCoord,
            waypoint: waypoint,
            target: target,
            curvature: curvature,
            cycles: cycles,
            waveAmplitude: waveAmplitude
        )
    } else {
        // Direct single-segment flight path
        rawPoints = generateSegment(
            start: startCoord,
            end: target,
            curvature: curvature,
            cycles: cycles,
            waveAmplitude: waveAmplitude,
            steps: 48,
            startPhase: 0.0,
            totalPhases: 1.0
        )
    }

    // Apply Chaikin corner smoothing to ensure 100% C1/C2 smooth curvature without sharp angles
    let fullPoints = smoothPointsChaikin(points: rawPoints, iterations: 2)

    let steps = fullPoints.count - 1

    // Directional flow arrows at ~25%, ~50%, and ~75% along trajectory
    var flowArrows: [TrajectoryFlowArrow] = []
    let arrowStepIndices = [steps / 4, steps / 2, (steps * 3) / 4]
    for stepIdx in arrowStepIndices {
        if stepIdx + 1 < fullPoints.count {
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
    }

    // Last telemetry checkpoint at ~80% along the trajectory
    let checkpointIdx = min(steps - 1, max(1, Int(Double(steps) * 0.80)))
    let p1 = fullPoints[checkpointIdx]
    let p2 = fullPoints[checkpointIdx + 1]

    let deltaLat = p2.latitude - p1.latitude
    let deltaLon = p2.longitude - p1.longitude
    let angleRad = atan2(deltaLon, deltaLat)
    let angleDeg = angleRad * 180.0 / .pi

    // Calculate Carrier Ingress Approach (Airbase -> Launch Sector / Start Coordinate)
    var carrierApproachPoints: [CLLocationCoordinate2D]? = nil
    if let carrier = carrierOrigin {
        var approach: [CLLocationCoordinate2D] = []
        let appSteps = 24
        let appMidLat = (carrier.latitude + startCoord.latitude) / 2.0
        let appMidLon = (carrier.longitude + startCoord.longitude) / 2.0
        let dLatApp = (startCoord.latitude - carrier.latitude) * 111.0
        let dLonApp = (startCoord.longitude - carrier.longitude) * 111.0 * cos(carrier.latitude * .pi / 180.0)
        let appDist = max(0.1, sqrt(dLatApp * dLatApp + dLonApp * dLonApp))
        let appCurvatureScale = min(0.25, max(0.05, appDist * 0.0003))
        
        let appNormalLat = -(startCoord.longitude - carrier.longitude) / max(0.01, sqrt(pow(startCoord.latitude - carrier.latitude, 2) + pow(startCoord.longitude - carrier.longitude, 2)))
        let appNormalLon = (startCoord.latitude - carrier.latitude) / max(0.01, sqrt(pow(startCoord.latitude - carrier.latitude, 2) + pow(startCoord.longitude - carrier.longitude, 2)))
        let appControlLat = appMidLat + appNormalLat * appCurvatureScale
        let appControlLon = appMidLon + appNormalLon * appCurvatureScale

        for i in 0...appSteps {
            let t = Double(i) / Double(appSteps)
            let invT = 1.0 - t
            let lat = invT * invT * carrier.latitude + 2.0 * invT * t * appControlLat + t * t * startCoord.latitude
            let lon = invT * invT * carrier.longitude + 2.0 * invT * t * appControlLon + t * t * startCoord.longitude
            approach.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        carrierApproachPoints = smoothPointsChaikin(points: approach, iterations: 1)
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

// MARK: - Multi-Waypoint Aerodynamic Turn Arc Generator

private func generateMultiWaypointSmoothSpline(
    start: CLLocationCoordinate2D,
    waypoint: CLLocationCoordinate2D,
    target: CLLocationCoordinate2D,
    curvature: Double,
    cycles: Double,
    waveAmplitude: Double
) -> [CLLocationCoordinate2D] {
    // Vector 1: Start -> Waypoint
    let dLat1 = waypoint.latitude - start.latitude
    let dLon1 = waypoint.longitude - start.longitude
    let dist1 = max(0.1, sqrt(dLat1 * dLat1 + dLon1 * dLon1))

    // Vector 2: Waypoint -> Target
    let dLat2 = target.latitude - waypoint.latitude
    let dLon2 = target.longitude - waypoint.longitude
    let dist2 = max(0.1, sqrt(dLat2 * dLat2 + dLon2 * dLon2))

    // Determine turn fillet transition fraction (smoothly cuts the corner 25-35% before/after waypoint)
    let filletFraction = min(0.35, max(0.15, 0.40 * min(dist1, dist2) / max(dist1, dist2, 0.1)))

    // Entry point A along Start -> Waypoint
    let entryA = CLLocationCoordinate2D(
        latitude: waypoint.latitude - (dLat1 * filletFraction),
        longitude: waypoint.longitude - (dLon1 * filletFraction)
    )

    // Exit point B along Waypoint -> Target
    let exitB = CLLocationCoordinate2D(
        latitude: waypoint.latitude + (dLat2 * filletFraction),
        longitude: waypoint.longitude + (dLon2 * filletFraction)
    )

    // 1. Ingress Leg: Start -> Entry A
    let ingress = generateSegment(
        start: start,
        end: entryA,
        curvature: curvature * 0.4,
        cycles: cycles * 0.4,
        waveAmplitude: waveAmplitude * 0.8,
        steps: 16,
        startPhase: 0.0,
        totalPhases: 0.35
    )

    // 2. Smooth Aerodynamic Banked Turn Arc: Entry A -> Exit B using Waypoint as Bezier control point
    var turnArc: [CLLocationCoordinate2D] = []
    let turnSteps = 16
    for i in 1...turnSteps {
        let t = Double(i) / Double(turnSteps)
        let invT = 1.0 - t
        // Quadratic Bezier arc: (1-t)^2 * A + 2(1-t)t * Waypoint + t^2 * B
        let bLat = invT * invT * entryA.latitude + 2.0 * invT * t * waypoint.latitude + t * t * exitB.latitude
        let bLon = invT * invT * entryA.longitude + 2.0 * invT * t * waypoint.longitude + t * t * exitB.longitude
        turnArc.append(CLLocationCoordinate2D(latitude: bLat, longitude: bLon))
    }

    // 3. Egress Leg: Exit B -> Target
    let egress = generateSegment(
        start: exitB,
        end: target,
        curvature: -curvature * 0.4,
        cycles: cycles * 0.4,
        waveAmplitude: waveAmplitude * 0.8,
        steps: 16,
        startPhase: 0.65,
        totalPhases: 0.35
    )

    return ingress + turnArc + egress.dropFirst()
}

// MARK: - Internal Aerodynamic Spline Segment Generator

private func generateSegment(
    start: CLLocationCoordinate2D,
    end: CLLocationCoordinate2D,
    curvature: Double,
    cycles: Double,
    waveAmplitude: Double,
    steps: Int,
    startPhase: Double,
    totalPhases: Double
) -> [CLLocationCoordinate2D] {
    let dLat = end.latitude - start.latitude
    let dLon = end.longitude - start.longitude
    let distance = max(0.1, sqrt(dLat * dLat + dLon * dLon))

    let normalLat = -dLon / distance
    let normalLon = dLat / distance

    let midLat = (start.latitude + end.latitude) / 2.0
    let midLon = (start.longitude + end.longitude) / 2.0

    let controlLat = midLat + normalLat * (distance * curvature)
    let controlLon = midLon + normalLon * (distance * curvature)

    var points: [CLLocationCoordinate2D] = []
    for i in 0...steps {
        let t = Double(i) / Double(steps)
        let invT = 1.0 - t

        let baseLat = invT * invT * start.latitude + 2.0 * invT * t * controlLat + t * t * end.latitude
        let baseLon = invT * invT * start.longitude + 2.0 * invT * t * controlLon + t * t * end.longitude

        let tangentLat = 2.0 * invT * (controlLat - start.latitude) + 2.0 * t * (end.latitude - controlLat)
        let tangentLon = 2.0 * invT * (controlLon - start.longitude) + 2.0 * t * (end.longitude - controlLon)
        let tLen = max(0.0001, sqrt(tangentLat * tangentLat + tangentLon * tangentLon))

        let localPerpLat = -tangentLon / tLen
        let localPerpLon = tangentLat / tLen

        let globalT = startPhase + t * totalPhases
        let envelope = sin(globalT * .pi)
        let snakeOffset = sin(globalT * .pi * 2.0 * cycles) * envelope * (distance * waveAmplitude)

        let finalLat = baseLat + localPerpLat * snakeOffset
        let finalLon = baseLon + localPerpLon * snakeOffset

        points.append(CLLocationCoordinate2D(latitude: finalLat, longitude: finalLon))
    }
    return points
}

// MARK: - Chaikin Corner Smoothing Algorithm

/// Smooths out any residual angular sharp vertices into silky, continuous aerodynamic curves (C1/C2 continuous)
private func smoothPointsChaikin(points: [CLLocationCoordinate2D], iterations: Int = 2) -> [CLLocationCoordinate2D] {
    guard points.count >= 3 else { return points }
    var current = points

    for _ in 0..<iterations {
        var smoothed: [CLLocationCoordinate2D] = []
        if let first = current.first {
            smoothed.append(first)
        }

        for i in 0..<(current.count - 1) {
            let p0 = current[i]
            let p1 = current[i + 1]

            // Point Q at 25% from p0 to p1
            let qLat = 0.75 * p0.latitude + 0.25 * p1.latitude
            let qLon = 0.75 * p0.longitude + 0.25 * p1.longitude

            // Point R at 75% from p0 to p1
            let rLat = 0.25 * p0.latitude + 0.75 * p1.latitude
            let rLon = 0.25 * p0.longitude + 0.75 * p1.longitude

            smoothed.append(CLLocationCoordinate2D(latitude: qLat, longitude: qLon))
            smoothed.append(CLLocationCoordinate2D(latitude: rLat, longitude: rLon))
        }

        if let last = current.last {
            smoothed.append(last)
        }
        current = smoothed
    }
    return current
}
