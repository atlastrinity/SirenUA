import SwiftUI
import MapKit

/// Модель сегмента траєкторії для створення плавного звуження від старту до цілі
struct TrajectorySegmentSlice: Identifiable {
    let id: Int
    let coordinates: [CLLocationCoordinate2D]
    let progress: Double // 0.0 на старті (широкий хвіст), 1.0 біля цілі (вузьке вістря)
}

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

    private func buildTaperedSlices(points: [CLLocationCoordinate2D], sliceCount: Int = 16) -> [TrajectorySegmentSlice] {
        guard points.count >= 2 else { return [] }
        let n = points.count
        let m = min(sliceCount, n - 1)
        var slices: [TrajectorySegmentSlice] = []

        for i in 0..<m {
            let startIdx = (i * (n - 1)) / m
            let endIdx = min(n - 1, ((i + 1) * (n - 1)) / m + 1)
            if endIdx > startIdx {
                let slicePoints = Array(points[startIdx...min(n - 1, endIdx)])
                let progress = Double(i) / Double(max(1, m - 1))
                slices.append(TrajectorySegmentSlice(id: i, coordinates: slicePoints, progress: progress))
            }
        }
        return slices
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
                        Color.white.opacity(0.40),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round, dash: [5, 5])
                    )
                    .mapOverlayLevel(level: .aboveLabels)
            }

            if n >= 2 {
                let slices = buildTaperedSlices(points: trajectory.fullPoints, sliceCount: 16)

                // 1. Шар 1: Плавний ореол розмиття (Aura Glow), що плавно звужується від 15pt на старті до 2.5pt біля цілі
                ForEach(slices) { slice in
                    let glowWidth = 15.0 - (slice.progress * 12.5) // 15.0 -> 2.5
                    let glowOpacity = 0.28 - (slice.progress * 0.16) // 0.28 -> 0.12
                    MapPolyline(coordinates: slice.coordinates)
                        .stroke(
                            color.opacity(glowOpacity),
                            style: StrokeStyle(lineWidth: glowWidth, lineCap: .round, lineJoin: .round)
                        )
                        .mapOverlayLevel(level: .aboveLabels)
                }

                // 2. Шар 2: Плавне основне тіло вектору (Kinetic Beam), що плавно звужується від 6.5pt до 1.8pt
                ForEach(slices) { slice in
                    let beamWidth = 6.5 - (slice.progress * 4.7) // 6.5 -> 1.8
                    let beamOpacity = 0.70 + (slice.progress * 0.25) // 0.70 -> 0.95
                    MapPolyline(coordinates: slice.coordinates)
                        .stroke(
                            color.opacity(beamOpacity),
                            style: StrokeStyle(lineWidth: beamWidth, lineCap: .round, lineJoin: .round)
                        )
                        .mapOverlayLevel(level: .aboveLabels)
                }

                // 3. Шар 3: Висококонтрастне центральне ядро (Razor Core), що звужується від 2.8pt до 1.0pt (гостре вістря)
                ForEach(slices) { slice in
                    let coreWidth = 2.8 - (slice.progress * 1.8) // 2.8 -> 1.0
                    MapPolyline(coordinates: slice.coordinates)
                        .stroke(
                            Color(red: 1.0, green: 0.98, blue: 0.85).opacity(0.96),
                            style: StrokeStyle(lineWidth: coreWidth, lineCap: .round, lineJoin: .round)
                        )
                        .mapOverlayLevel(level: .aboveLabels)
                }

                // 4. Шар 4: Акцентна біла голка на вістрі підльоту (останні 25% траєкторії)
                MapPolyline(coordinates: Array(trajectory.fullPoints.suffix(max(2, n * 25 / 100))))
                    .stroke(
                        Color.white.opacity(0.98),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveLabels)
            }
        }
    }
}
