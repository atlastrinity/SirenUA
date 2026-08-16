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
                launchSectorName: launchSectorName
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

            if n >= 2 {
                // 1. Шар 1: М'який радарний ореол розмиття (Atmospheric Aura Glow) — суцільна лінія без артефактів нарізання
                MapPolyline(coordinates: trajectory.fullPoints)
                    .stroke(
                        color.opacity(0.24),
                        style: StrokeStyle(lineWidth: 6.0, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)

                // 2. Шар 2: Насичене основне тіло тактичного вектору (Kinetic Tactical Beam)
                MapPolyline(coordinates: trajectory.fullPoints)
                    .stroke(
                        color.opacity(0.90),
                        style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)

                // 3. Шар 3: Висококонтрастне центральне ядро (Razor Luminous Core)
                MapPolyline(coordinates: trajectory.fullPoints)
                    .stroke(
                        Color(red: 1.0, green: 0.98, blue: 0.90).opacity(0.96),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)

                // 4. Шар 4: Акуратна тактична стрілочка на вістрі траєкторії перед кружечком області ("як у стрілі")
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
