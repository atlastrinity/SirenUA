import SwiftUI
import MapKit

/// Окремий шар розрахунку та малювання траєкторій руху загроз (доступний лише для Premium)
struct PremiumTrajectoryOverlay: MapContent {
    let targetCoordinate: CLLocationCoordinate2D
    let threatType: String?
    let customOrigin: CLLocationCoordinate2D?
    let color: Color
    let isPremium: Bool

    init(
        targetCoordinate: CLLocationCoordinate2D,
        threatType: String?,
        customOrigin: CLLocationCoordinate2D? = nil,
        color: Color = .yellow,
        isPremium: Bool
    ) {
        self.targetCoordinate = targetCoordinate
        self.threatType = threatType
        self.customOrigin = customOrigin
        self.color = color
        self.isPremium = isPremium
    }

    var body: some MapContent {
        // Траєкторії (лінії польоту) малюються ВИКЛЮЧНО для Premium користувачів
        if isPremium {
            let trajectory = calculateTrajectory(target: targetCoordinate, threatType: threatType, customOrigin: customOrigin)
            let n = trajectory.fullPoints.count

            if n >= 2 {
                // 1. Широкий розмитий хвіст траєкторії (0%→70%)
                MapPolyline(coordinates: Array(trajectory.fullPoints.prefix(max(2, n * 70 / 100))))
                    .stroke(
                        color.opacity(0.22),
                        style: StrokeStyle(lineWidth: 11.0, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)

                // 2. Основна контрастна лінія вектору (0%→100%)
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
