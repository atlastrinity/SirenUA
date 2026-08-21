import SwiftUI
import MapKit

// MARK: - Arrowhead Shape ("Акуратна стрілочка, як у стрілі")

public struct ArrowheadShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let topY = rect.minY
        let bottomY = rect.maxY
        let leftX = rect.minX
        let rightX = rect.maxX
        let notchY = rect.minY + rect.height * 0.65

        path.move(to: CGPoint(x: midX, y: topY))
        path.addLine(to: CGPoint(x: rightX, y: bottomY))
        path.addLine(to: CGPoint(x: midX, y: notchY))
        path.addLine(to: CGPoint(x: leftX, y: bottomY))
        path.closeSubpath()

        return path
    }
}

// MARK: - Trajectory Arrowhead View

public struct TrajectoryArrowheadView: View {
    public let color: Color
    public let angle: Double
    public var heading: Double = 0.0
    public var zoomScale: CGFloat = 1.0
    public var echelonIndex: Int = 0
    public var totalEchelonCount: Int = 1

    @State private var isPulsing = false

    public init(
        color: Color,
        angle: Double,
        heading: Double = 0.0,
        zoomScale: CGFloat = 1.0,
        echelonIndex: Int = 0,
        totalEchelonCount: Int = 1
    ) {
        self.color = color
        self.angle = angle
        self.heading = heading
        self.zoomScale = zoomScale
        self.echelonIndex = echelonIndex
        self.totalEchelonCount = totalEchelonCount
    }

    public var body: some View {
        ZStack(alignment: .center) {
            // 1. Soft pulse ring radiating from arrowhead
            Circle()
                .stroke(color.opacity(isPulsing ? 0.0 : (echelonIndex == 0 ? 0.60 : 0.40)), lineWidth: 1.0)
                .frame(width: 20, height: 20)
                .scaleEffect(isPulsing ? 1.5 : 0.8, anchor: .center)
                .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false).delay(Double(echelonIndex) * 0.25), value: isPulsing)

            // 2. Tactical Arrowhead Body ("як у стрілі")
            ZStack {
                // Background Arrowhead Gradient Fill (Inherits exact threat color)
                ArrowheadShape()
                    .fill(
                        LinearGradient(
                            colors: [Color.white, color.opacity(0.95), color],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Central Luminous Spine Rib (3D Facet Effect)
                Path { path in
                    path.move(to: CGPoint(x: 5.5, y: 0))
                    path.addLine(to: CGPoint(x: 5.5, y: 9.0))
                }
                .stroke(Color.white, lineWidth: 1.0)

                // Razor White Outer Stroke
                ArrowheadShape()
                    .stroke(
                        Color.white.opacity(0.95),
                        style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round)
                    )
            }
            .frame(width: 11, height: 14)
            .shadow(color: color.opacity(0.95), radius: 4, x: 0, y: 0)
            .shadow(color: .black.opacity(0.70), radius: 3, x: 0, y: 1)
        }
        .frame(width: 36, height: 36, alignment: .center)
        .rotationEffect(.degrees(angle - heading))
        .scaleEffect(zoomScale, anchor: .center)
        .onAppear {
            isPulsing = true
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Carrier Approach Direction View (Airbase Ingress Vector Indicator)

public struct CarrierApproachDirectionView: View {
    public let angle: Double
    public var heading: Double = 0.0
    public var zoomScale: CGFloat = 1.0
    public var iconName: String = "airplane"

    public init(
        angle: Double,
        heading: Double = 0.0,
        zoomScale: CGFloat = 1.0,
        iconName: String = "airplane"
    ) {
        self.angle = angle
        self.heading = heading
        self.zoomScale = zoomScale
        self.iconName = iconName
    }

    public var body: some View {
        ZStack {
            // Tactical frosted pill background to ensure high contrast against any terrain
            Circle()
                .fill(Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.85))
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.50), lineWidth: 0.9)
                )
                .shadow(color: Color.black.opacity(0.60), radius: 3, x: 0, y: 1)

            // Carrier aircraft silhouette aligned with ingress heading
            Image(systemName: iconName)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(Color.white.opacity(0.95))
                .rotationEffect(.degrees(angle - heading))
        }
        .scaleEffect(min(1.20, max(0.85, zoomScale)))
        .allowsHitTesting(false)
    }
}

// MARK: - Trajectory Flow Chevron View (Directional Pulsing Arrow + Threat Icon)

public struct TrajectoryFlowChevronView: View {
    public let angle: Double
    public var heading: Double = 0.0
    public let threatIcon: String
    public let threatLabel: String
    public let opacity: Double
    
    @State private var isPulsing = false

    public init(angle: Double, heading: Double = 0.0, threatIcon: String, threatLabel: String, opacity: Double) {
        self.angle = angle
        self.heading = heading
        self.threatIcon = threatIcon
        self.threatLabel = threatLabel
        self.opacity = opacity
    }
    
    public var body: some View {
        VStack(alignment: .center, spacing: 2) {
            ZStack(alignment: .center) {
                // Symmetrical Centered Pulse Ring (no layout shift)
                Circle()
                    .stroke(Color.yellow.opacity(isPulsing ? 0.0 : 0.75), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                    .scaleEffect(isPulsing ? 1.8 : 0.9, anchor: .center)
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
                    .frame(width: 18, height: 18)
                    .shadow(color: .orange.opacity(0.6), radius: 4)
                
                // Direction chevron + threat icon
                Image(systemName: threatIcon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(angle - heading - 90))
            }
            .frame(width: 40, height: 40, alignment: .center)
            
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

// MARK: - FlyingThreatMarkerView (Стійкий концентричний радарний маркер цілі)

public struct FlyingThreatMarkerView: View {
    public let regionName: String
    public let threatType: String?
    public let threatLabel: String
    public let confidence: Int?
    public let eta: String?
    public let color: Color
    public let isPredictive: Bool
    public let isPremium: Bool
    
    @State private var isPulsing = false
    
    public init(
        regionName: String,
        threatType: String?,
        threatLabel: String,
        confidence: Int?,
        eta: String?,
        color: Color,
        isPredictive: Bool,
        isPremium: Bool = false
    ) {
        self.regionName = regionName
        self.threatType = threatType
        self.threatLabel = threatLabel
        self.confidence = confidence
        self.eta = eta
        self.color = color
        self.isPredictive = isPredictive
        self.isPremium = isPremium
    }

    public var iconName: String {
        return ThreatConstants.sfSymbol(for: threatType)
    }
    
    public var body: some View {
        VStack(alignment: .center, spacing: 2) {
            if isPremium {
                // Фіксований квадратний контейнер (44x44) гарантує 100% симетричне концентричне розширення без горизонтального зміщення
                ZStack(alignment: .center) {
                    // Концентричне пульсуюче кільце 1 (Radar primary wave)
                    Circle()
                        .stroke(color.opacity(isPulsing ? 0.0 : 0.90), lineWidth: 2.0)
                        .frame(width: 24, height: 24)
                        .scaleEffect(isPulsing ? 1.85 : 0.90, anchor: .center)
                        .animation(
                            .easeOut(duration: 1.6).repeatForever(autoreverses: false),
                            value: isPulsing
                        )

                    // Концентричне пульсуюче кільце 2 (Radar secondary echo)
                    Circle()
                        .stroke(color.opacity(isPulsing ? 0.0 : 0.50), lineWidth: 1.2)
                        .frame(width: 24, height: 24)
                        .scaleEffect(isPulsing ? 2.30 : 0.90, anchor: .center)
                        .animation(
                            .easeOut(duration: 1.6).delay(0.3).repeatForever(autoreverses: false),
                            value: isPulsing
                        )

                    // Центральний тактичний маяк (Weapon Badge Core)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.0))
                        .shadow(color: color.opacity(0.7), radius: 6, x: 0, y: 1)

                    // Іконка типу загрози
                    Image(systemName: iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 56, height: 56, alignment: .center)
                .onAppear {
                    isPulsing = true
                }
            }

            // Інформаційна плашка з назвою та деталями загрози
            VStack(alignment: .center, spacing: 2) {
                Text(regionName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if isPremium {
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
                                .monospacedDigit()
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
        }
        .frame(alignment: .center)
    }
}

// MARK: - LastTelemetryCheckpointView (Точка останнього уточнення координат)

public struct LastTelemetryCheckpointView: View {
    public let angle: Double
    public let color: Color
    
    @State private var isPulsing = false

    public init(angle: Double, color: Color) {
        self.angle = angle
        self.color = color
    }
    
    public var body: some View {
        VStack(alignment: .center, spacing: 3) {
            ZStack(alignment: .center) {
                // Pulse Ring (Centered)
                Circle()
                    .stroke(Color.yellow, lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                    .scaleEffect(isPulsing ? 1.7 : 0.85, anchor: .center)
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
                    .frame(width: 14, height: 14)
                    .shadow(color: .orange, radius: 4)
                
                Image(systemName: "chevron.forward")
                    .font(.system(size: 7, weight: .black))
                    .foregroundColor(.black)
                    .rotationEffect(.degrees(angle - 90))
            }
            .frame(width: 36, height: 36, alignment: .center)
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
        .frame(alignment: .center)
    }
}

// MARK: - Trajectory Origin Marker (Точка вильоту / Рубіж пуску)

public struct TrajectoryOriginMarkerView: View {
    public let color: Color
    public var zoomScale: CGFloat = 1.0
    public var originName: String? = nil

    @State private var isPulsing = false

    public init(color: Color, zoomScale: CGFloat = 1.0, originName: String? = nil) {
        self.color = color
        self.zoomScale = zoomScale
        self.originName = originName
    }

    /// Короткий тактичний підпис локації для компактного та рівномірного відображення на карті
    private var tacticalShortName: String? {
        guard let raw = originName?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let lower = raw.lowercased()
        
        // 1. Морські та стратегічні акваторії
        if lower.contains("чорн") && lower.contains("мор") { return "ЧОРНЕ МОРЕ" }
        if lower.contains("азов") && lower.contains("мор") { return "АЗОВСЬКЕ МОРЕ" }
        if lower.contains("каспій") { return "КАСПІЙ" }
        
        // 2. Стаціонарні полігони, позиції та миси
        if lower.contains("чауд") { return "МИС ЧАУДА" }
        if lower.contains("тарханкут") { return "МИС ТАРХАНКУТ" }
        if lower.contains("капустін") { return "КАПУСТІН ЯР" }
        if lower.contains("кінбурн") { return "КІНБУРНСЬКА КОСА" }

        // 3. Стаціонарні авіабази та майданчики базування
        if lower.contains("халін") || lower.contains("халин") { return "ХАЛІНО" }
        if lower.contains("сеща") { return "СЕЩА" }
        if lower.contains("шайковк") { return "ШАЙКОВКА" }
        if lower.contains("енгельс") || lower.contains("саратов") { return "ЕНГЕЛЬС" }
        if lower.contains("олень") { return "ОЛЕНЬЯ" }
        if lower.contains("саваслейк") { return "САВАСЛЕЙКА" }
        if lower.contains("моздок") { return "МОЗДОК" }
        if lower.contains("ахтуб") { return "АХТУБІНСЬК" }
        if lower.contains("балтім") || lower.contains("балтим") { return "БАЛТИМОР" }
        if lower.contains("бутурлин") { return "БУТУРЛИНІВКА" }
        if lower.contains("дягіл") || lower.contains("дягил") { return "ДЯГІЛЄВО" }
        if lower.contains("сольц") { return "СОЛЬЦІ" }
        if lower.contains("липецьк") || lower.contains("липецк") { return "ЛИПЕЦЬК" }
        if lower.contains("морозов") { return "МОРОЗОВСЬК" }
        if lower.contains("приморськ") || lower.contains("ахтарськ") { return "ПРИМОРСЬКО-АХТАРСЬК" }
        if lower.contains("єйськ") || lower.contains("ейск") { return "ЄЙСЬК" }
        if lower.contains("міллер") || lower.contains("миллер") { return "МІЛЛЄРОВО" }
        if lower.contains("кущев") { return "КУЩЕВСЬКА" }
        if lower.contains("таганрог") { return "ТАГАНРОГ" }
        if lower.contains("кримськ") || lower.contains("крымск") { return "КРИМСЬК" }
        if lower.contains("севастопол") || lower.contains("бельбек") { return "БЕЛЬБЕК" }
        if lower.contains("саки") || lower.contains("новофедор") { return "САКИ" }
        if lower.contains("гвардій") || lower.contains("гвардей") { return "ГВАРДІЙСЬКЕ" }
        if lower.contains("джанкой") { return "ДЖАНКОЙ" }
        if lower.contains("мачулищ") { return "МАЧУЛИЩІ" }
        if lower.contains("білорус") || lower.contains("рб") || lower.contains("гомел") { return "БІЛОРУСЬ" }

        // 4. Прикордонні та тактичні пускові рубежі
        if lower.contains("курськ") || lower.contains("курск") { return "КУРСЬКИЙ РУБІЖ" }
        if lower.contains("бєлгород") || lower.contains("белгород") { return "БЄЛГОРОДСЬКИЙ РУБІЖ" }
        if lower.contains("брянськ") || lower.contains("брянск") { return "БРЯНСЬКИЙ РУБІЖ" }
        if lower.contains("воронеж") { return "ВОРОНЕЗЬКИЙ РУБІЖ" }
        if lower.contains("ростов") { return "РОСТОВСЬКИЙ РУБІЖ" }
        if lower.contains("орел") || lower.contains("орлов") { return "ОРЛОВСЬКИЙ РУБІЖ" }
        if lower.contains("рязань") || lower.contains("тула") { return "РУБІЖ РЯЗАНЬ / ТУЛА" }
        if lower.contains("запоріз") { return "РУБІЖ ТОТ ЗАПОРІЖЖЯ" }
        if lower.contains("херсон") { return "РУБІЖ ТОТ ХЕРСОН" }
        if lower.contains("донец") || lower.contains("донецьк") { return "РУБІЖ ТОТ ДОНЕЧЧИНА" }
        if lower.contains("луган") { return "РУБІЖ ТОТ ЛУГАНЩИНА" }

        // 5. Очищення дужок для універсального виводу
        var name = raw
        if let parenRange = name.range(of: "\\s*\\(.*\\)", options: .regularExpression) {
            let withoutParen = name.replacingCharacters(in: parenRange, with: "").trimmingCharacters(in: .whitespaces)
            if !withoutParen.isEmpty {
                name = withoutParen
            }
        }
        return name.uppercased()
    }

    public var body: some View {
        ZStack(alignment: .center) {
            // 1. Концентричні пульсуючі радіолокаційні кільця (360° симетричний радар навколо центру точки)
            Circle()
                .stroke(color.opacity(isPulsing ? 0.0 : 0.90), lineWidth: 1.8)
                .frame(width: 20, height: 20)
                .scaleEffect(isPulsing ? 2.20 : 0.70, anchor: .center)
                .animation(
                    .easeOut(duration: 1.6).repeatForever(autoreverses: false),
                    value: isPulsing
                )

            Circle()
                .stroke(color.opacity(isPulsing ? 0.0 : 0.45), lineWidth: 1.0)
                .frame(width: 20, height: 20)
                .scaleEffect(isPulsing ? 2.80 : 0.70, anchor: .center)
                .animation(
                    .easeOut(duration: 1.6).delay(0.3).repeatForever(autoreverses: false),
                    value: isPulsing
                )

            // 2. Біле тактичне контрастне кільце
            Circle()
                .stroke(Color.white.opacity(0.95), lineWidth: 1.4)
                .frame(width: 12, height: 12)

            // 3. Центральна контрастна точка вильоту
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white, color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.95), radius: 4)

            // 4. Текстовий бейдж з назвою локації (розміщений під точкою без зміщення геометричного центру точки)
            if let shortName = tacticalShortName {
                HStack(spacing: 3) {
                    Image(systemName: "smallcircle.filled.circle.fill")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(color)

                    Text(shortName)
                        .font(.system(size: 7.5, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.88))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color.opacity(0.85), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.6), radius: 3, x: 0, y: 1.5)
                .offset(y: 19)
                .fixedSize()
            }
        }
        .frame(width: 32, height: 32, alignment: .center)
        .scaleEffect(zoomScale, anchor: .center)
        .onAppear { isPulsing = true }
        .allowsHitTesting(false)
    }
}
