import SwiftUI
import MapKit

/// Окремий шар розрахунку та малювання траєкторій руху загроз (доступний лише для Premium)
struct PremiumTrajectoryOverlay: MapContent {
    let targetCoordinate: CLLocationCoordinate2D
    let threatType: String?
    let customOrigin: CLLocationCoordinate2D?
    let carrierOrigin: CLLocationCoordinate2D?
    let launchSector: CLLocationCoordinate2D?
    let carrierOriginName: String?
    let launchSectorName: String?
    let color: Color
    var cameraDistance: Double = 600_000.0
    var zoomScale: CGFloat = 1.0
    let isPremium: Bool

    init(
        targetCoordinate: CLLocationCoordinate2D,
        threatType: String?,
        customOrigin: CLLocationCoordinate2D? = nil,
        carrierOrigin: CLLocationCoordinate2D? = nil,
        launchSector: CLLocationCoordinate2D? = nil,
        carrierOriginName: String? = nil,
        launchSectorName: String? = nil,
        color: Color = .yellow,
        cameraDistance: Double = 600_000.0,
        zoomScale: CGFloat = 1.0,
        isPremium: Bool
    ) {
        self.targetCoordinate = targetCoordinate
        self.threatType = threatType
        self.customOrigin = customOrigin
        self.carrierOrigin = carrierOrigin
        self.launchSector = launchSector
        self.carrierOriginName = carrierOriginName
        self.launchSectorName = launchSectorName
        self.color = color
        self.cameraDistance = cameraDistance
        self.zoomScale = zoomScale
        self.isPremium = isPremium
    }

    var body: some MapContent {
        // Траєкторії (лінії польоту) малюються ВИКЛЮЧНО для Premium користувачів
        if isPremium {
            let trajectory = calculateTrajectory(
                target: targetCoordinate,
                threatType: threatType,
                customOrigin: customOrigin,
                carrierOrigin: carrierOrigin,
                launchSector: launchSector,
                carrierOriginName: carrierOriginName,
                launchSectorName: launchSectorName,
                cameraDistance: cameraDistance,
                zoomScale: zoomScale
            )
            let n = trajectory.fullPoints.count

            // 0. Стратегічний шар підльоту носія (Пунктир від аеродрому до рубежу пуску)
            if let approach = trajectory.carrierApproachPoints, approach.count >= 2 {
                MapPolyline(coordinates: approach)
                    .stroke(
                        Color.white.opacity(0.45),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round, dash: [6, 6])
                    )
                    .mapOverlayLevel(level: .aboveLabels)
            }

            if !trajectory.taperedSegments.isEmpty {
                // Динамічне аеродинамічне звуження: широкий початок на рубежі запуску -> плавне звуження до області
                ForEach(trajectory.taperedSegments) { segment in
                    // Шар 1: М'який радарний ореол розмиття (Atmospheric Aura Glow)
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(
                            color.opacity(segment.glowOpacity),
                            style: StrokeStyle(lineWidth: segment.glowWidth, lineCap: .round, lineJoin: .round)
                        )
                        .mapOverlayLevel(level: .aboveLabels)

                    // Шар 2: Насичене основне тіло тактичного вектору (Kinetic Tactical Beam)
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(
                            color.opacity(segment.beamOpacity),
                            style: StrokeStyle(lineWidth: segment.beamWidth, lineCap: .round, lineJoin: .round)
                        )
                        .mapOverlayLevel(level: .aboveLabels)

                    // Шар 3: Висококонтрастне центральне ядро (Razor Luminous Core)
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(
                            Color(red: 1.0, green: 0.98, blue: 0.90).opacity(segment.coreOpacity),
                            style: StrokeStyle(lineWidth: segment.coreWidth, lineCap: .round, lineJoin: .round)
                        )
                        .mapOverlayLevel(level: .aboveLabels)
                }

                // Шар 4: Акуратна тактична стрілочка на вістрі траєкторії (безшовно сполучена з лінією на відстані від кружечка області)
                Annotation(coordinate: trajectory.tipCoordinate) {
                    TrajectoryArrowheadView(
                        color: color,
                        angle: trajectory.tipAngle,
                        zoomScale: zoomScale
                    )
                } label: {
                    EmptyView()
                }
            } else if n >= 2 {
                // Резервне відображення цільної лінії (Fallback)
                MapPolyline(coordinates: trajectory.fullPoints)
                    .stroke(
                        color.opacity(0.24),
                        style: StrokeStyle(lineWidth: 6.0, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)

                MapPolyline(coordinates: trajectory.fullPoints)
                    .stroke(
                        color.opacity(0.90),
                        style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)

                MapPolyline(coordinates: trajectory.fullPoints)
                    .stroke(
                        Color(red: 1.0, green: 0.98, blue: 0.90).opacity(0.96),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)

                Annotation(coordinate: trajectory.tipCoordinate) {
                    TrajectoryArrowheadView(
                        color: color,
                        angle: trajectory.tipAngle,
                        zoomScale: zoomScale
                    )
                } label: {
                    EmptyView()
                }
            }
        }
    }
}
