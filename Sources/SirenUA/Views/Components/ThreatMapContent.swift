import SwiftUI
import MapKit

struct ThreatMapContent: MapContent {
    let safeRegions: [RegionPolygon]
    let activeThreatRegions: [RegionPolygon]
    let activeAlertRegions: [RegionPolygon]
    let alertsDict: [String: AlertRegion]
    let alerts: [AlertRegion]
    let isPremium: Bool
    let lastAlertedRegionName: String?
    let allFoundShelters: [MKMapItem]
    let selectedShelter: MKMapItem?
    let route: MKRoute?
    let timeRefreshTrigger: Date
    let currentUserCoordinate: CLLocationCoordinate2D
    var zoomScale: CGFloat = 1.0
    let getThreatTypeDescriptionShort: (String) -> String
    let onRegionSelected: (AlertRegion) -> Void

    var flyingThreatAlerts: [AlertRegion] {
        alerts.filter { shouldShowFlyingThreat(for: $0) }
    }
    
    var statusBadgeAlerts: [AlertRegion] {
        alerts.filter { alert in
            if shouldShowFlyingThreat(for: alert) {
                return false
            }
            if alert.isActive { return true }
            if alert.threatLevel == nil && alert.activeThreats.isEmpty { return true }
            if !alert.isActive && alert.threatLevel != nil { return true }
            return false
        }
    }

    var body: some MapContent {
        // Polygons for safe regions (Clean Deep Midnight Blue)
        ForEach(safeRegions) { region in
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(Color.cyan.opacity(0.20), lineWidth: 0.35)
                    .foregroundStyle(Color(red: 0.04, green: 0.14, blue: 0.38).opacity(0.32))
                    .mapOverlayLevel(level: .aboveRoads)
            }
        }

        // Polygons for threat zones (Vibrant Juicy Yellow / Orange Glow)
        ForEach(activeThreatRegions) { region in
            let threatColor = alertsDict[region.nameUK]?.color ?? .yellow
            let confidence = alertsDict[region.nameUK]?.threatConfidence ?? 75
            let fillOpacity: Double = confidence >= 85 ? 0.65 : (confidence >= 60 ? 0.52 : 0.40)
            let fillColor: Color = threatColor.opacity(fillOpacity)
            
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(threatColor.opacity(0.50), lineWidth: 0.45)
                    .foregroundStyle(fillColor)
                    .mapOverlayLevel(level: .aboveRoads)
            }
        }

        // Polygons for official active alert regions (Vivid Bright Red Glow)
        ForEach(activeAlertRegions) { region in
            let isLastAlerted = region.nameUK == lastAlertedRegionName
            let redFill = isLastAlerted ? Color(red: 0.96, green: 0.11, blue: 0.16).opacity(0.68) : Color(red: 0.91, green: 0.13, blue: 0.19).opacity(0.58)
            
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(Color.red.opacity(0.55), lineWidth: 0.45)
                    .foregroundStyle(redFill)
                    .mapOverlayLevel(level: .aboveRoads)
            }
        }
        
        // User Location Marker
        Annotation("Моє місцезнаходження", coordinate: currentUserCoordinate) {
            Image(systemName: "location.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(6)
                .background(Color.green)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 5)
                .scaleEffect(zoomScale)
                .allowsHitTesting(false)
        }
        
        // Regional threat level, status badges, and flying threat overlays
        ForEach(alerts) { alert in
            if shouldShowFlyingThreat(for: alert) {
                FlyingThreatMapOverlay(
                    alert: alert,
                    zoomScale: zoomScale,
                    getThreatTypeDescriptionShort: getThreatTypeDescriptionShort,
                    onRegionSelected: onRegionSelected
                )
            } else {
                RegionStatusBadgeAnnotation(
                    alert: alert,
                    timeRefreshTrigger: timeRefreshTrigger,
                    zoomScale: zoomScale,
                    getThreatTypeDescriptionShort: getThreatTypeDescriptionShort,
                    onRegionSelected: onRegionSelected
                )
            }
        }

        // Nearby shelters markers
        ForEach(allFoundShelters, id: \.self) { shelter in
            Marker(shelter.name ?? "Укриття", systemImage: "figure.walk.arrival", coordinate: shelter.placemark.coordinate)
                .tint(selectedShelter == shelter ? .green : .blue)
                .tag(shelter)
        }
        
        // Active GPS Route
        if let route = route {
            MapPolyline(route)
                .stroke(.blue, lineWidth: 5)
        }
    }
}

// MARK: - Region Status Badge Annotation MapContent

struct RegionStatusBadgeAnnotation: MapContent {
    let alert: AlertRegion
    let timeRefreshTrigger: Date
    var zoomScale: CGFloat = 1.0
    let getThreatTypeDescriptionShort: (String) -> String
    let onRegionSelected: (AlertRegion) -> Void

    var body: some MapContent {
        let isThreatActive = !alert.isActive && alert.threatLevel != nil
        let badgeIcon: String = alert.isActive ? "exclamationmark.triangle.fill" : (isThreatActive ? alert.icon : "checkmark.circle.fill")
        let badgeBgColor: Color = alert.isActive ? .red : (isThreatActive ? alert.color : .green)

        Annotation(coordinate: alert.coordinate) {
            VStack(spacing: 4) {
                Image(systemName: badgeIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(badgeBgColor)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                    .shadow(radius: 3)
                
                VStack(spacing: 1) {
                    let _ = timeRefreshTrigger
                    Text(alert.name)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                    
                    if isThreatActive {
                        let type = alert.currentThreat?.type ?? alert.threatType
                        let desc = getThreatTypeDescriptionShort(type ?? "")
                        Text(desc.isEmpty || desc == "Загроза" ? "Загроза підльоту" : desc)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.yellow)
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                    }
                    
                    if isThreatActive {
                        HStack(spacing: 3) {
                            if let conf = alert.threatConfidence {
                                Text("⚙️ \(conf)%")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(conf >= 85 ? .red : (conf >= 60 ? .orange : .yellow))
                            }
                            if let eta = alert.displayETA, !eta.isEmpty {
                                Text(eta)
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    } else if !alert.isActive {
                        Text("Без тривоги")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.green.opacity(0.9))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(badgeBgColor.opacity(0.3), lineWidth: 0.5)
                )
            }
            .scaleEffect(zoomScale)
            .onTapGesture {
                onRegionSelected(alert)
            }
        } label: {
            EmptyView()
        }
    }
}

// MARK: - Flying Threat Map Overlay MapContent

struct FlyingThreatMapOverlay: MapContent {
    let alert: AlertRegion
    var zoomScale: CGFloat = 1.0
    let getThreatTypeDescriptionShort: (String) -> String
    let onRegionSelected: (AlertRegion) -> Void

    var body: some MapContent {
        let threatType = alert.currentThreat?.type ?? alert.threatType
        let threatLabel = alert.currentThreat?.threatLabel ?? getThreatTypeDescriptionShort(threatType ?? "")
        let confidence = alert.currentThreat?.confidence ?? alert.threatConfidence
        let eta = alert.currentThreat?.dynamicETA ?? alert.displayETA
        let color = alert.color
        let customOrigin = alert.currentThreat?.originCoordinate
        let trajectory = calculateTrajectory(target: alert.coordinate, threatType: threatType, customOrigin: customOrigin)

        // 0. Comet Outer Dust Coma (16 smooth gradient sub-polyline segments)
        ForEach(0..<trajectory.cometTailSegments.count, id: \.self) { idx in
            let seg = trajectory.cometTailSegments[idx]
            MapPolyline(coordinates: seg.points)
                .stroke(
                    color.opacity(seg.outerOpacity),
                    style: StrokeStyle(lineWidth: seg.outerWidth, lineCap: .round, lineJoin: .round)
                )
                .mapOverlayLevel(level: .aboveLabels)
        }

        // 1. Sleek Dark Base Isolation Layer (Single Polyline pass, 48 smooth points)
        MapPolyline(coordinates: trajectory.fullPoints)
            .stroke(Color.black.opacity(0.70), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
            .mapOverlayLevel(level: .aboveLabels)

        // 2. Continuous Solid Neon Core Path (Single Polyline pass, 48 smooth points)
        MapPolyline(coordinates: trajectory.fullPoints)
            .stroke(
                Color(red: 1.0, green: 0.92, blue: 0.0).opacity(0.92),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
            .mapOverlayLevel(level: .aboveLabels)

        // 3. Concentrated White Laser Focus Head (Single Polyline pass, 16 smooth points)
        MapPolyline(coordinates: Array(trajectory.fullPoints.suffix(max(2, trajectory.fullPoints.count / 3))))
            .stroke(
                Color.white,
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
            )
            .mapOverlayLevel(level: .aboveLabels)

        // 6. Intermediate Detection Checkpoint Threat Object Badge
        Annotation(coordinate: trajectory.lastCheckpointCoordinate) {
            TrajectoryFlowChevronView(
                angle: trajectory.lastCheckpointAngle,
                threatIcon: threatIconName(for: threatType),
                threatLabel: threatLabel.isEmpty ? "Виявлено" : threatLabel,
                opacity: 0.95
            )
            .scaleEffect(zoomScale)
            .allowsHitTesting(false)
        } label: {
            EmptyView()
        }

        // 7. Target Region Destination Flying Threat Badge
        Annotation(coordinate: alert.coordinate) {
            FlyingThreatMarkerView(
                regionName: alert.name,
                threatType: threatType,
                threatLabel: threatLabel.isEmpty ? "Загроза" : threatLabel,
                confidence: confidence,
                eta: eta,
                color: color,
                isPredictive: alert.isThreatPredictive
            )
            .scaleEffect(zoomScale)
            .onTapGesture {
                onRegionSelected(alert)
            }
        } label: {
            EmptyView()
        }
    }
}

func threatIconName(for threatType: String?) -> String {
    return ThreatConstants.sfSymbol(for: threatType)
}

// MARK: - Flying Threat Visibility Logic

/// Визначає, чи слід показувати літаючі маркери загроз (БПЛА, ракети, траєкторії).
/// Значок БПЛА/ракети всередині області відображається ВИКЛЮЧНО коли оголошена офіційна тривога (alert.isActive == true).
/// Якщо в області немає тривоги (жовта область) — значок БПЛА всередині області НЕ показується!
func shouldShowFlyingThreat(for alert: AlertRegion) -> Bool {
    let isPredictive = alert.isThreatPredictive || (alert.currentThreat?.is_predictive ?? false)
    let hasThreatData = alert.threatType != nil || !alert.activeThreats.isEmpty || (alert.threatDetail != nil && !alert.threatDetail!.isEmpty) || isPredictive
    return (alert.isActive || isPredictive) && hasThreatData
}

// MARK: - Trajectory Flow Arrow Data

struct TrajectoryFlowArrow {
    let coordinate: CLLocationCoordinate2D
    let angle: Double
    let opacity: Double
}

// MARK: - Comet Tail Segment

struct CometTailSegment {
    let points: [CLLocationCoordinate2D]
    // Outer dust coma
    let outerWidth: CGFloat
    let outerOpacity: Double
    // Mid warm glow
    let midWidth: CGFloat
    let midOpacity: Double
    // Inner hot core
    let coreWidth: CGFloat
    let coreOpacity: Double
}

// MARK: - Trajectory Calculator (Comet Tail)

struct TrajectoryPath {
    let fullPoints: [CLLocationCoordinate2D]
    let cometTailSegments: [CometTailSegment]
    let flowArrows: [TrajectoryFlowArrow]
    let lastCheckpointCoordinate: CLLocationCoordinate2D
    let lastCheckpointAngle: Double
}

// MARK: - Trajectory Flow Chevron View (Directional Pulsing Arrow + Threat Icon)

struct TrajectoryFlowChevronView: View {
    let angle: Double
    let threatIcon: String
    let threatLabel: String
    let opacity: Double
    
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Pulse ring
                Circle()
                    .stroke(Color.yellow.opacity(isPulsing ? 0.0 : 0.7), lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                    .scaleEffect(isPulsing ? 1.8 : 0.9)
                    .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: isPulsing)
                
                // Icon background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.red.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                    .shadow(color: .orange.opacity(0.6), radius: 4)
                
                // Direction chevron + threat icon
                Image(systemName: threatIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(angle - 90))
            }
            
            // Mini threat label
            Text(threatLabel)
                .font(.system(size: 7, weight: .black, design: .rounded))
                .foregroundColor(.yellow)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.75))
                .cornerRadius(4)
        }
        .opacity(opacity)
        .onAppear { isPulsing = true }
    }
}

func calculateTrajectory(target: CLLocationCoordinate2D, threatType: String?, customOrigin: CLLocationCoordinate2D? = nil) -> TrajectoryPath {
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

    if let origin = customOrigin, originDistanceKm > 20.0 {
        // Use explicit custom origin coordinates if they represent a distinct origin point
        startLat = origin.latitude
        startLon = origin.longitude
    } else {
        // Otherwise, extrapolate origin back to state border / sea entry corridor
        switch threatType {
        case "shahed":
            if target.latitude > 49.5 {
                // Northern / Eastern target (Kharkiv, Sumy, Kyiv, Chernihiv, Poltava): project to Belgorod / Kursk border
                startLat = max(50.4, target.latitude + 0.6)
                startLon = max(36.4, target.longitude + 0.8)
            } else {
                // Southern / Western target (Odesa, Mykolaiv, Zaporizhzhia): project to Black Sea / Crimea border
                startLat = min(45.8, target.latitude - 1.2)
                startLon = max(30.5, target.longitude + 1.2)
            }
        case "cruise_missile", "tu95":
            // Cruise missile / Tu-95: project to Caspian Sea / East border
            startLat = max(48.5, target.latitude + 0.8)
            startLon = max(39.2, target.longitude + 3.2)
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

    // MARK: - Comet Tail Generation (16 smooth multi-point sub-polylines)
    let wMax = distance * 0.055  // Maximum coma width at tail origin
    var cometSegments: [CometTailSegment] = []
    let numSegments = 16
    let pointsPerSeg = steps / numSegments // 3 points per sub-polyline segment

    for segIdx in 0..<numSegments {
        let startPointIdx = segIdx * pointsPerSeg
        let endPointIdx = min(steps, (segIdx + 1) * pointsPerSeg)
        let segPoints = Array(fullPoints[startPointIdx...endPointIdx])

        let t0 = Double(startPointIdx) / Double(steps)
        let t1 = Double(endPointIdx) / Double(steps)

        let w0 = wMax * pow(1.0 - t0, 1.6)
        let w1 = wMax * pow(1.0 - t1, 1.6)
        let wAvg = (w0 + w1) * 0.5

        let progress = t0
        let outerOpacity = 0.28 * pow(1.0 - progress, 0.7)
        let midOpacity   = 0.42 * pow(1.0 - progress, 1.0)
        let coreOpacity  = 0.18 + 0.72 * pow(progress, 0.8)

        let outerPxRaw = CGFloat(wAvg * 420.0 / distance)
        let outerPx = max(4.0, min(22.0, outerPxRaw))
        let midPx   = max(2.0, min(12.0, outerPx * 0.52))
        let corePx  = max(1.2, min(5.0,  outerPx * 0.22))

        cometSegments.append(CometTailSegment(
            points: segPoints,
            outerWidth: outerPx,
            outerOpacity: outerOpacity,
            midWidth: midPx,
            midOpacity: midOpacity,
            coreWidth: corePx,
            coreOpacity: coreOpacity
        ))
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

    return TrajectoryPath(
        fullPoints: fullPoints,
        cometTailSegments: cometSegments,
        flowArrows: flowArrows,
        lastCheckpointCoordinate: p1,
        lastCheckpointAngle: angleDeg
    )
}

// MARK: - LastTelemetryCheckpointView (Точка останнього уточнення координат)

struct LastTelemetryCheckpointView: View {
    let angle: Double
    let color: Color
    
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                // Pulse Ring
                Circle()
                    .stroke(Color.yellow, lineWidth: 1.5)
                    .frame(width: 26, height: 26)
                    .scaleEffect(isPulsing ? 1.6 : 0.8)
                    .opacity(isPulsing ? 0.0 : 0.9)
                    .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: isPulsing)
                
                // Solid Radar Node
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 16, height: 16)
                    .shadow(color: .orange, radius: 4)
                
                Image(systemName: "chevron.forward")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.black)
                    .rotationEffect(.degrees(angle - 90))
            }
            .onAppear {
                isPulsing = true
            }
            
            // Checkpoint Badge Label
            HStack(spacing: 3) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.yellow)
                
                Text("УТОЧНЕННЯ КООРДИНАТ")
                    .font(.system(size: 7, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.80))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5).stroke(Color.yellow.opacity(0.7), lineWidth: 0.7)
            )
            .shadow(color: .black.opacity(0.5), radius: 4)
        }
    }
}

// MARK: - FlyingThreatMarkerView

struct FlyingThreatMarkerView: View {
    let regionName: String
    let threatType: String?
    let threatLabel: String
    let confidence: Int?
    let eta: String?
    let color: Color
    let isPredictive: Bool
    
    @State private var isPulsing = false
    
    var iconName: String {
        return ThreatConstants.sfSymbol(for: threatType)
    }
    
    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                // Radar pulse animation
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 38, height: 38)
                    .scaleEffect(isPulsing ? 1.5 : 0.9)
                    .opacity(isPulsing ? 0.0 : 0.8)
                    .animation(
                        .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                        value: isPulsing
                    )

                // Weapon Badge Background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .shadow(color: color.opacity(0.8), radius: 8, x: 0, y: 2)

                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .onAppear {
                isPulsing = true
            }

            // Visual Flying Tag ("Полтавська область • 🔴 ЛЕТИТЬ: БпЛА • 92%")
            VStack(spacing: 2) {
                Text(regionName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 4, height: 4)
                    
                    Text(threatLabel.uppercased())
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(.yellow)
                        .lineLimit(1)
                    
                    if let conf = confidence {
                        Text("\(conf)%")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Capsule())
                    }
                    
                    if let etaStr = eta, !etaStr.isEmpty {
                        Text(etaStr)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
        }
    }
}
