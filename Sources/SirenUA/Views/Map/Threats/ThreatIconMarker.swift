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
    public var zoomScale: CGFloat = 1.0

    @State private var isPulsing = false

    public init(color: Color, angle: Double, zoomScale: CGFloat = 1.0) {
        self.color = color
        self.angle = angle
        self.zoomScale = zoomScale
    }

    public var body: some View {
        ZStack(alignment: .center) {
            // 1. Soft pulse ring radiating from arrowhead
            Circle()
                .stroke(color.opacity(isPulsing ? 0.0 : 0.60), lineWidth: 1.0)
                .frame(width: 20, height: 20)
                .scaleEffect(isPulsing ? 1.5 : 0.8)
                .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)

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
        .frame(width: 28, height: 28, alignment: .center)
        .rotationEffect(.degrees(angle))
        .scaleEffect(zoomScale)
        .onAppear {
            isPulsing = true
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Trajectory Flow Chevron View (Directional Pulsing Arrow + Threat Icon)

public struct TrajectoryFlowChevronView: View {
    public let angle: Double
    public let threatIcon: String
    public let threatLabel: String
    public let opacity: Double
    
    @State private var isPulsing = false

    public init(angle: Double, threatIcon: String, threatLabel: String, opacity: Double) {
        self.angle = angle
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
                    .rotationEffect(.degrees(angle - 90))
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
