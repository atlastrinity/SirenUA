import SwiftUI
import MapKit

/// Окремий шар розрахунку та малювання траєкторій руху загроз (доступний лише для Premium)
struct PremiumTrajectoryOverlay: MapContent {
    let targetCoordinate: CLLocationCoordinate2D
    let threatType: String?
    let threatCount: Int
    let customOrigin: CLLocationCoordinate2D?
    let carrierOrigin: CLLocationCoordinate2D?
    let launchSector: CLLocationCoordinate2D?
    let carrierOriginName: String?
    let launchSectorName: String?
    let color: Color
    var cameraDistance: Double = 600_000.0
    var cameraHeading: Double = 0.0
    var zoomScale: CGFloat = 1.0
    let isPremium: Bool

    init(
        targetCoordinate: CLLocationCoordinate2D,
        threatType: String?,
        threatCount: Int = 1,
        customOrigin: CLLocationCoordinate2D? = nil,
        carrierOrigin: CLLocationCoordinate2D? = nil,
        launchSector: CLLocationCoordinate2D? = nil,
        carrierOriginName: String? = nil,
        launchSectorName: String? = nil,
        color: Color = .yellow,
        cameraDistance: Double = 600_000.0,
        cameraHeading: Double = 0.0,
        zoomScale: CGFloat = 1.0,
        isPremium: Bool
    ) {
        self.targetCoordinate = targetCoordinate
        self.threatType = threatType
        self.threatCount = max(1, threatCount)
        self.customOrigin = customOrigin
        self.carrierOrigin = carrierOrigin
        self.launchSector = launchSector
        self.carrierOriginName = carrierOriginName
        self.launchSectorName = launchSectorName
        self.color = color
        self.cameraDistance = cameraDistance
        self.cameraHeading = cameraHeading
        self.zoomScale = zoomScale
        self.isPremium = isPremium
    }

    var body: some MapContent {
        // Траєкторії (лінії польоту) малюються ВИКЛЮЧНО для Premium користувачів
        if isPremium {
            let trajectory = calculateTrajectory(
                target: targetCoordinate,
                threatType: threatType,
                threatCount: threatCount,
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

            // 1. РІВЕНЬ ДЕТАЛІЗАЦІЇ (LOD Level of Detail):
            // На оглядовому плані всієї України (> 450 км) малюємо 2 оптимізовані суцільні лінії (Glow + Core)
            // замість циклу багатьох сегментів, що зменшує GPU draw calls на 80%.
            if cameraDistance > 450_000.0 || trajectory.taperedSegments.isEmpty {
                if n >= 2 {
                    // Шар 1: Насичене основне тіло тактичного вектору (Kinetic Tactical Beam)
                    MapPolyline(coordinates: trajectory.fullPoints)
                        .stroke(
                            color.opacity(0.88),
                            style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                        )
                        .mapOverlayLevel(level: .aboveLabels)

                    // Шар 2: Висококонтрастне центральне ядро (Razor Luminous Core)
                    MapPolyline(coordinates: trajectory.fullPoints)
                        .stroke(
                            Color(red: 1.0, green: 0.98, blue: 0.90).opacity(0.95),
                            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                        )
                        .mapOverlayLevel(level: .aboveLabels)

                    // Шар 3: Тактичний маркер точки вильоту / Рубежу пуску (Origin Pulse Dot)
                    if let originCoord = trajectory.fullPoints.first {
                        Annotation(coordinate: originCoord) {
                            TrajectoryOriginMarkerView(
                                color: color,
                                zoomScale: zoomScale,
                                originName: launchSectorName ?? carrierOriginName
                            )
                        } label: {
                            EmptyView()
                        }
                    }

                    // Шар 4: Акуратні тактичні стрілочки (головна на вістрі + ешелон загроз у колоні)
                    ForEach(trajectory.echelonArrowheads) { arrowhead in
                        Annotation(coordinate: arrowhead.coordinate) {
                            TrajectoryArrowheadView(
                                color: color,
                                angle: arrowhead.angle,
                                heading: cameraHeading,
                                zoomScale: zoomScale,
                                echelonIndex: arrowhead.echelonIndex,
                                totalEchelonCount: arrowhead.totalEchelonCount
                            )
                        } label: {
                            EmptyView()
                        }
                    }
                }
            } else {
                // На наближеному плані (<= 450 км): Аеродинамічне звуження через конічні сегменти
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

                // Шар 4: Тактичний маркер точки вильоту / Рубежу пуску (Origin Pulse Dot)
                if let originCoord = trajectory.fullPoints.first {
                    Annotation(coordinate: originCoord) {
                        TrajectoryOriginMarkerView(
                            color: color,
                            zoomScale: zoomScale,
                            originName: launchSectorName ?? carrierOriginName
                        )
                    } label: {
                        EmptyView()
                    }
                }

                // Шар 5: Тактичні стрілочки (головна на вістрі + ешелон загроз у колоні)
                ForEach(trajectory.echelonArrowheads) { arrowhead in
                    Annotation(coordinate: arrowhead.coordinate) {
                        TrajectoryArrowheadView(
                            color: color,
                            angle: arrowhead.angle,
                            heading: cameraHeading,
                            zoomScale: zoomScale,
                            echelonIndex: arrowhead.echelonIndex,
                            totalEchelonCount: arrowhead.totalEchelonCount
                        )
                    } label: {
                        EmptyView()
                    }
                }
            }
        }
    }
}
