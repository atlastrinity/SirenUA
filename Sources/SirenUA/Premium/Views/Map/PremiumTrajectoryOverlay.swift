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
    let showOriginMarker: Bool
    let showApproachLine: Bool
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
        showOriginMarker: Bool = true,
        showApproachLine: Bool = true,
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
        self.showOriginMarker = showOriginMarker
        self.showApproachLine = showApproachLine
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
            if showApproachLine, let approach = trajectory.carrierApproachPoints, approach.count >= 2 {
                MapPolyline(coordinates: approach)
                    .stroke(
                        Color.white.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round, dash: [6, 6])
                    )
                    .mapOverlayLevel(level: .aboveLabels)

                // Тактичний індикатор напрямку підльоту носія (Мікро-силует літака)
                if let carrierMarker = trajectory.carrierApproachMarker {
                    Annotation(coordinate: carrierMarker.coordinate) {
                        CarrierApproachDirectionView(
                            angle: carrierMarker.angle,
                            heading: cameraHeading,
                            zoomScale: zoomScale,
                            iconName: carrierMarker.iconName
                        )
                    } label: {
                        EmptyView()
                    }
                }
            }

            // 1. Тактичний неоновий вектор траєкторії (Atmospheric Aura Glow + Kinetic Tactical Beam + Razor Luminous Core)
            // Плавний 3-шаровий вектор забезпечує однакове яскраве світіння на будь-якому масштабі карти без мерехтіння чи стрибків LOD.
            if n >= 2 {
                // Шар 1: М'який радарний неоновий ореол (Atmospheric Aura Glow)
                MapPolyline(coordinates: trajectory.fullPoints)
                    .stroke(
                        color.opacity(0.35),
                        style: StrokeStyle(lineWidth: 6.0, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)

                // Шар 2: Насичене основне тіло тактичного вектору (Kinetic Tactical Beam)
                MapPolyline(coordinates: trajectory.fullPoints)
                    .stroke(
                        color.opacity(0.92),
                        style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)

                // Шар 3: Висококонтрастне центральне ядро (Razor Luminous Core)
                MapPolyline(coordinates: trajectory.fullPoints)
                    .stroke(
                        Color(red: 1.0, green: 0.98, blue: 0.90).opacity(0.96),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)

                // Шар 4: Тактичний маркер точки вильоту / Рубежу пуску (Origin Pulse Dot)
                if showOriginMarker, let originCoord = trajectory.fullPoints.first {
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
