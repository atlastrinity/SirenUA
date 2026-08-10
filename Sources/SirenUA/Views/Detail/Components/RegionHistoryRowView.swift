import SwiftUI

/// Timeline row card component for historical threat events
struct RegionHistoryRowView: View {
    let event: RegionHistoryEvent
    let isLast: Bool
    let nextEventLevel: String?
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Timeline spine
            VStack(spacing: 0) {
                // Dot
                ZStack {
                    Circle()
                        .fill(threatTypeColor(event.threat_type, level: event.threat_level).opacity(0.2))
                        .frame(width: 28, height: 28)
                    Circle()
                        .fill(levelColor(event.threat_level))
                        .frame(width: 12, height: 12)
                }
                
                // Connecting line
                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    levelColor(event.threat_level).opacity(0.3),
                                    levelColor(nextEventLevel ?? "none").opacity(0.3)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 28)
            
            // Event card
            eventCard(event)
                .padding(.bottom, isLast ? 0 : 12)
        }
    }
    
    private func eventCard(_ event: RegionHistoryEvent) -> some View {
        HStack(spacing: 0) {
            // Left accent vertical stripe
            Rectangle()
                .fill(threatTypeColor(event.threat_type, level: event.threat_level))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 10) {
                // Top row: type icon + name + time
                HStack(alignment: .center, spacing: 8) {
                    Text(event.typeIcon)
                        .font(.system(size: 18))
                    
                    Text(event.typeName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text(event.displayTime)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                // Level badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(levelColor(event.threat_level))
                        .frame(width: 7, height: 7)
                    
                    Text(levelLabel(event.threat_level))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(levelColor(event.threat_level))
                    
                    if let conf = event.confidence {
                        Spacer()
                        Text("⚙️ \(conf)%")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                
                // Detail text (if present)
                if let detail = event.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineSpacing(3)
                        .lineLimit(3)
                }
            }
            .padding(14)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(threatTypeColor(event.threat_type, level: event.threat_level).opacity(0.15), lineWidth: 1)
        )
    }
    
    private func levelColor(_ level: String) -> Color {
        switch level {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return Color(red: 0.4, green: 0.8, blue: 1.0)
        case "none": return .green
        default: return .gray
        }
    }
    
    private func threatTypeColor(_ type: String?, level: String) -> Color {
        if type == "official_alarm" {
            return level == "none" ? .green : .red
        }
        switch type {
        case "shahed": return .yellow
        case "kab": return .orange
        case "ballistic", "iskander": return .red
        case "mig31k", "tu95": return .purple
        case "cruise_missile": return Color(red: 1.0, green: 0.2, blue: 0.4)
        default: return .gray
        }
    }
    
    private func levelLabel(_ level: String) -> String {
        switch level {
        case "critical": return "Критичний"
        case "high": return "Високий"
        case "medium": return "Середній"
        case "low": return "Низький"
        case "none": return "Відбій"
        default: return level
        }
    }
}
