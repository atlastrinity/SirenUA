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
    let getThreatTypeDescriptionShort: (String) -> String
    let onRegionSelected: (AlertRegion) -> Void

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
        
        // User current location marker
        Annotation("Ви", coordinate: currentUserCoordinate) {
            Image(systemName: "location.north.fill")
                .foregroundColor(.white)
                .padding(8)
                .background(Color.green)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 5)
        }
        
        // Regional threat level and status badges
        // Show badges for: active alerts, safe regions, AND threat regions where flying markers are suppressed
        ForEach(alerts.filter { alert in
            // Always show active alert badges
            if alert.isActive { return true }
            // Always show safe region badges
            if alert.threatLevel == nil && alert.activeThreats.isEmpty { return true }
            // Show badges for threat regions where we DON'T render flying markers
            // (low/medium threats without official alert — they only get colored polygon, no БПЛА)
            if !alert.isActive && alert.threatLevel != nil {
                let showsFlying = shouldShowFlyingThreat(for: alert)
                return !showsFlying // Show badge only if flying marker is suppressed
            }
            return false
        }) { alert in
            let isThreatActive = !alert.isActive && alert.threatLevel != nil
            let badgeIcon: String = alert.isActive ? "exclamationmark.triangle.fill" : (isThreatActive ? alert.icon : "checkmark.circle.fill")
            let badgeBgColor: Color = alert.isActive ? .red : (isThreatActive ? alert.color : .green)

            Annotation(coordinate: alert.coordinate) {
                VStack(spacing: 4) {
                    Button(action: {
                        onRegionSelected(alert)
                    }) {
                        Image(systemName: badgeIcon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(badgeBgColor)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                            .shadow(radius: 3)
                    }
                    
                    VStack(spacing: 1) {
                        let _ = timeRefreshTrigger
                        Text(alert.name)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                        
                        if isThreatActive, let type = alert.threatType {
                            Text(getThreatTypeDescriptionShort(type))
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
            } label: {
                EmptyView()
            }
        }
        
        // Flying threat targets annotations (Drones / Missiles / Ballistics)
        // CRITICAL RULE: We trust the official alert status.
        // БПЛА/ракети показуються ТІЛЬКИ коли:
        //   1. isActive == true (офіційна тривога оголошена), АБО
        //   2. threatLevel == critical/high з підтвердженою (non-predictive) загрозою та confidence >= 75%
        // Для low/medium загроз без офіційної тривоги — тільки жовтий/оранжевий полігон,
        // щоб не вводити в оману: якщо область жовта — БПЛА НЕ показуємо.
        ForEach(alerts.filter { shouldShowFlyingThreat(for: $0) }) { alert in
            let threatType = alert.currentThreat?.type ?? alert.threatType
            let threatLabel = alert.currentThreat?.threatLabel ?? getThreatTypeDescriptionShort(threatType ?? "")
            let confidence = alert.currentThreat?.confidence ?? alert.threatConfidence
            let eta = alert.currentThreat?.dynamicETA ?? alert.displayETA
            let color = alert.color
            let customOrigin = alert.currentThreat?.originCoordinate
            let trajectory = calculateTrajectory(target: alert.coordinate, threatType: threatType, customOrigin: customOrigin)

            // 0. Continuous 100% Solid Black Isolation Base (Completely masks red/yellow region polygons underneath!)
            MapPolyline(coordinates: trajectory.fullPoints)
                .stroke(Color.black, style: StrokeStyle(lineWidth: 10.0, lineCap: .round, lineJoin: .round))
                .mapOverlayLevel(level: .aboveLabels)

            // 1. Continuous Dissolving Comet Nebula Glow (Vivid Electric Neon Yellow Mist ON TOP over ALL regions!)
            ForEach(trajectory.segments) { seg in
                MapPolyline(coordinates: seg.coordinates)
                    .stroke(
                        Color(red: 1.0, green: 0.95, blue: 0.0).opacity(seg.outerOpacity * 1.25),
                        style: StrokeStyle(lineWidth: seg.outerWidth, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)
            }

            // 2. Continuous 100% SOLID OPAQUE Pure Neon Yellow Comet Core Stripe (Laid 100% ON TOP, 0% color bleed!)
            MapPolyline(coordinates: trajectory.fullPoints)
                .stroke(
                    Color(red: 1.0, green: 0.95, blue: 0.0),
                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
                )
                .mapOverlayLevel(level: .aboveLabels)

            // 3. Razor-Sharp Opaque White Laser Core near Target Head
            ForEach(trajectory.segments.filter { $0.isHead }) { seg in
                MapPolyline(coordinates: seg.coordinates)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)
            }

            // 2. Single "Point of Last Coordinate Clarification" (📍 УТОЧНЕННЯ КООРДИНАТ)
            Annotation(coordinate: trajectory.lastCheckpointCoordinate) {
                LastTelemetryCheckpointView(
                    angle: trajectory.lastCheckpointAngle,
                    color: color
                )
            } label: {
                EmptyView()
            }

            // Target Region Destination Flying Threat Badge
            Annotation(coordinate: alert.coordinate) {
                Button(action: {
                    onRegionSelected(alert)
                }) {
                    FlyingThreatMarkerView(
                        threatType: threatType,
                        threatLabel: threatLabel.isEmpty ? "Загроза" : threatLabel,
                        confidence: confidence,
                        eta: eta,
                        color: color,
                        isPredictive: alert.isThreatPredictive
                    )
                }
            } label: {
                EmptyView()
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

// MARK: - Flying Threat Visibility Logic

/// Визначає, чи слід показувати літаючі маркери загроз (БПЛА, ракети, траєкторії).
/// ФУНДАМЕНТАЛЬНЕ ПРАВИЛО: БПЛА та ракети у просторі області відображаються ТІЛЬКИ коли
/// оголошена повітряна тривога (alert.isActive == true).
/// Якщо тривоги немає — літаючі маркери БПЛА НЕ рендеряться, щоб не створювати фальшивих загроз.
func shouldShowFlyingThreat(for alert: AlertRegion) -> Bool {
    return alert.isActive
}

// MARK: - Aerodynamic Trajectory Flow Arrow View

struct TrajectoryFlowArrowView: View {
    let angle: Double
    let opacity: Double
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(opacity * 0.35))
                .frame(width: 14, height: 14)
            
            Image(systemName: "chevron.up")
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.yellow.opacity(opacity))
                .rotationEffect(.degrees(angle))
                .shadow(color: .yellow, radius: 2)
        }
    }
}

// MARK: - Trajectory Calculator (Proportional Aerodynamic Comet Tail & Flow)

struct CometTrajectorySegment: Identifiable {
    let id: Int
    let coordinates: [CLLocationCoordinate2D]
    let outerWidth: CGFloat
    let outerOpacity: Double
    let innerWidth: CGFloat
    let innerOpacity: Double
    let isHead: Bool
}

struct TrajectoryFlowArrow: Identifiable {
    let id: Int
    let coordinate: CLLocationCoordinate2D
    let angle: Double
    let opacity: Double
}

struct TrajectoryPath {
    let fullPoints: [CLLocationCoordinate2D]
    let segments: [CometTrajectorySegment]
    let flowArrows: [TrajectoryFlowArrow]
    let lastCheckpointCoordinate: CLLocationCoordinate2D
    let lastCheckpointAngle: Double
}

func calculateTrajectory(target: CLLocationCoordinate2D, threatType: String?, customOrigin: CLLocationCoordinate2D? = nil) -> TrajectoryPath {
    let latOffset: Double
    let lonOffset: Double
    let curvature: Double
    
    switch threatType {
    case "shahed":
        latOffset = -3.2  // Coming from Black Sea / Crimea / South-East
        lonOffset = 3.6
        curvature = -0.22 // Smooth aerodynamic arc
    case "cruise_missile", "tu95":
        latOffset = 1.4   // Coming from Caspian Sea / East
        lonOffset = 4.8
        curvature = 0.20
    case "ballistic", "iskander":
        latOffset = 3.2   // Coming from North / Belgorod / Kursk
        lonOffset = 2.2
        curvature = -0.18
    case "kab":
        latOffset = 0.9   // Coming from Frontline / Border
        lonOffset = 1.6
        curvature = 0.15
    default:
        latOffset = -2.4
        lonOffset = 3.0
        curvature = 0.20
    }
    
    let startLat: Double
    let startLon: Double

    if let origin = customOrigin {
        startLat = origin.latitude
        startLon = origin.longitude
    } else {
        startLat = target.latitude + latOffset
        startLon = target.longitude + lonOffset
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
    let steps = 48
    for i in 0...steps {
        let t = Double(i) / Double(steps)
        let invT = 1.0 - t
        
        let lat = invT * invT * startLat + 2.0 * invT * t * controlLat + t * t * target.latitude
        let lon = invT * invT * startLon + 2.0 * invT * t * controlLon + t * t * target.longitude
        
        fullPoints.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }
    
    // Create 24 continuous micro-segments with fluffy expanded dissolving comet tail (52px wide nebula mist at origin)
    let segmentCount = 24
    var segments: [CometTrajectorySegment] = []
    
    for i in 0..<segmentCount {
        let startIdx = i * (steps / segmentCount)
        let endIdx = min((i + 1) * (steps / segmentCount) + 1, steps)
        
        let subPoints = Array(fullPoints[startIdx...endIdx])
        let progress = Double(i) / Double(segmentCount - 1) // 0.0 at tail origin -> 1.0 at target head
        
        // Fluffy Dissolving Mist Taper:
        // Tail (progress = 0.0): Ultra-wide (52px), soft, heavily blurred atmospheric mist fading out into the distance
        // Head (progress = 1.0): Sharp, focused, solid laser beam
        let tailMistFactor = pow(1.0 - progress, 1.2)
        let headBeamFactor = pow(progress, 1.6)
        
        let outerWidth: CGFloat = 34.0 * CGFloat(tailMistFactor) + 4.0
        let outerOpacity: Double = 0.03 * tailMistFactor + 0.94 * headBeamFactor
        
        let innerWidth: CGFloat = 1.0 + CGFloat(progress * 3.8)
        let innerOpacity: Double = 0.10 + (pow(progress, 1.2) * 0.90)
        let isHead = (i >= segmentCount - 5)
        
        segments.append(
            CometTrajectorySegment(
                id: i,
                coordinates: subPoints,
                outerWidth: outerWidth,
                outerOpacity: outerOpacity,
                innerWidth: innerWidth,
                innerOpacity: innerOpacity,
                isHead: isHead
            )
        )
    }
    
    // Aerodynamic directional flow chevrons along orbit (at ~30% and ~60% progress)
    var flowArrows: [TrajectoryFlowArrow] = []
    let arrowStepIndices = [14, 28]
    
    for (idx, stepIdx) in arrowStepIndices.enumerated() {
        let p1 = fullPoints[stepIdx]
        let p2 = fullPoints[min(stepIdx + 1, steps)]
        
        let deltaLat = p2.latitude - p1.latitude
        let deltaLon = p2.longitude - p1.longitude
        let angleRad = atan2(deltaLon, deltaLat)
        let angleDeg = angleRad * 180.0 / .pi
        let progress = Double(stepIdx) / Double(steps)
        let opacity = 0.30 + (progress * 0.55)
        
        flowArrows.append(
            TrajectoryFlowArrow(
                id: idx,
                coordinate: p1,
                angle: angleDeg,
                opacity: opacity
            )
        )
    }
    
    let checkpointIdx = 36 // ~75% along 48 steps
    let p1 = fullPoints[checkpointIdx]
    let p2 = fullPoints[min(checkpointIdx + 1, steps)]
    
    let deltaLat = p2.latitude - p1.latitude
    let deltaLon = p2.longitude - p1.longitude
    let angleRad = atan2(deltaLon, deltaLat)
    let angleDeg = angleRad * 180.0 / .pi
    
    return TrajectoryPath(
        fullPoints: fullPoints,
        segments: segments,
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
    let threatType: String?
    let threatLabel: String
    let confidence: Int?
    let eta: String?
    let color: Color
    let isPredictive: Bool
    
    @State private var isPulsing = false
    
    var iconName: String {
        switch threatType {
        case "shahed":          return "paperplane.fill"
        case "cruise_missile":  return "bolt.horizontal.fill"
        case "ballistic":       return "arrow.up.right.circle.fill"
        case "mig31k":          return "airplane"
        case "kab":             return "flame.fill"
        case "tu95":            return "airplane.circle.fill"
        case "iskander":        return "cross.circle.fill"
        case "artillery":       return "burst.fill"
        default:                return "exclamationmark.triangle.fill"
        }
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

            // Visual Flying Tag ("🔴 ЛЕТИТЬ: БпЛА • 92%")
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
                
                Text(threatLabel.uppercased())
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                if let conf = confidence {
                    Text("\(conf)%")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(color.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 2)
        }
    }
}
