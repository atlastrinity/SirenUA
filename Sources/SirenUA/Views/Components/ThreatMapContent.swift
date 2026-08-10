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
        // Isolated static polygon layer (safe, threat, and active alert region fills)
        RegionPolygonsLayer(
            safeRegions: safeRegions,
            activeThreatRegions: activeThreatRegions,
            activeAlertRegions: activeAlertRegions,
            alertsDict: alertsDict,
            lastAlertedRegionName: lastAlertedRegionName
        )
        
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

// MARK: - Region Polygons Isolated MapContent

struct RegionPolygonsLayer: MapContent {
    let safeRegions: [RegionPolygon]
    let activeThreatRegions: [RegionPolygon]
    let activeAlertRegions: [RegionPolygon]
    let alertsDict: [String: AlertRegion]
    let lastAlertedRegionName: String?

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
            let fillColor: Color = threatColor.opacity(0.62)
            
            ForEach(region.identifiablePolygons) { item in
                MapPolygon(item.polygon)
                    .stroke(threatColor.opacity(0.85), lineWidth: 0.75)
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

        // MARK: - Tapering Tail (3-Layer Streamlined GPU Render)
        let n = trajectory.fullPoints.count

        // 1. Wide Diffuse Outer Glow Tail (0%→70%)
        MapPolyline(coordinates: Array(trajectory.fullPoints.prefix(max(2, n * 70 / 100))))
            .stroke(
                color.opacity(0.22),
                style: StrokeStyle(lineWidth: 11.0, lineCap: .round, lineJoin: .round)
            )
            .mapOverlayLevel(level: .aboveLabels)

        // 2. High-Contrast Core Trajectory Line (0%→100%)
        MapPolyline(coordinates: trajectory.fullPoints)
            .stroke(
                Color(red: 1.0, green: 0.92, blue: 0.0).opacity(0.95),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
            .mapOverlayLevel(level: .aboveLabels)

        // 3. Focused White Hot-Spot Target Head (35%→100%)
        MapPolyline(coordinates: Array(trajectory.fullPoints.suffix(max(2, n * 35 / 100))))
            .stroke(
                Color.white.opacity(0.92),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
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

// MARK: - Trajectory Calculator

struct TrajectoryPath {
    let fullPoints: [CLLocationCoordinate2D]
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
        case "tu22m3":
            // Ту-22М3: Шайковка (54.22, 34.36) або Моздок (43.78, 44.60)
            // Для північних цілей — Шайковка, для південних — Моздок
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

    return TrajectoryPath(
        fullPoints: fullPoints,
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
