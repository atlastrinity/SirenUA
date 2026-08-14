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

            // 0. Стратегічний шар носія (Пунктирний підліт літака від аеродрому до рубежу скиду)
            if let approach = trajectory.carrierApproachPoints, approach.count >= 2 {
                MapPolyline(coordinates: approach)
                    .stroke(
                        Color.white.opacity(0.40),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round, dash: [5, 5])
                    )
                    .mapOverlayLevel(level: .aboveLabels)
            }

            if n >= 2 {
                // 1. Широкий розмитий хвіст траєкторії боєприпасу (0%→70%)
                MapPolyline(coordinates: Array(trajectory.fullPoints.prefix(max(2, n * 70 / 100))))
                    .stroke(
                        color.opacity(0.22),
                        style: StrokeStyle(lineWidth: 11.0, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)

                // 2. Основна контрастна лінія вектору удару (0%→100%)
                MapPolyline(coordinates: trajectory.fullPoints)
                    .stroke(
                        Color(red: 1.0, green: 0.92, blue: 0.0).opacity(0.95),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)

                // 3. Акцентна біла голова вектора в місці підльоту (35%→100%)
                MapPolyline(coordinates: Array(trajectory.fullPoints.suffix(max(2, n * 35 / 100))))
                    .stroke(
                        Color.white.opacity(0.92),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)
            }
        }
    }
}

