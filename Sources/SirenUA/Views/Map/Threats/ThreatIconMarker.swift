import SwiftUI
import MapKit

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
        VStack(spacing: 2) {
            ZStack {
                // Pulse ring
                Circle()
                    .stroke(Color.yellow.opacity(isPulsing ? 0.0 : 0.7), lineWidth: 1.5)
                    .frame(width: 28, height: 28)
                    .scaleEffect(isPulsing ? 1.8 : 0.9)
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
                    .frame(width: 22, height: 22)
                    .shadow(color: .orange.opacity(0.6), radius: 4)
                
                // Direction chevron + threat icon
                Image(systemName: threatIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(angle - 90))
            }
            
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

// MARK: - FlyingThreatMarkerView

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
        VStack(spacing: 3) {
            if isPremium {
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
            }

            // Visual Flying Tag ("Полтавська область")
            VStack(spacing: 2) {
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
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
        }
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
