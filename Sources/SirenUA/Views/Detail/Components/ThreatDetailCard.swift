import SwiftUI

struct ThreatDetailCard: View {
    let detail: String
    let threat: SingleThreatInfo?
    let themeColor: Color
    let timeRefreshTrigger: Date

    var body: some View {
        let lines = detail.components(separatedBy: "\n")
        let descriptionLines = lines.filter { !isTelemetryLine($0) }
        let telemetryLines = lines.filter { isTelemetryLine($0) }
        
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(themeColor)
                        .font(.system(size: 14))
                    Text("Що відомо")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                if let threat = threat, let dynamic = threat.dynamicETA {
                    let _ = timeRefreshTrigger
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(dynamic)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeColor.opacity(0.12))
                    .cornerRadius(8)
                    .foregroundStyle(themeColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeColor.opacity(0.25), lineWidth: 1)
                    )
                }
            }
            
            if let threat = threat {
                let originInfo = ThreatConstants.originLabel(for: threat.type, detail: threat.detail)
                let carrierName: String? = {
                    if let n = threat.carrier_origin_name, !n.isEmpty { return n }
                    return ThreatConstants.carrierOrigin(for: threat.type, detail: threat.detail)
                }()

                if let carrierName = carrierName, !carrierName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: originInfo.icon)
                            .foregroundStyle(themeColor)
                            .font(.system(size: 12))
                        Text(originInfo.title)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(carrierName)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(themeColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }

                let sectorName: String? = {
                    if let s = threat.launch_sector_name, !s.isEmpty { return s }
                    return ThreatConstants.launchSector(for: threat.type, detail: threat.detail)
                }()

                if let sector = sectorName, !sector.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "safari.fill")
                            .foregroundStyle(themeColor)
                            .font(.system(size: 12))
                        Text("Рубіж / Коридор:")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(sector)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(themeColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                }
            }

            if !descriptionLines.isEmpty {
                Text(descriptionLines.joined(separator: "\n"))
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(6)
            }
            
            if !telemetryLines.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(telemetryLines, id: \.self) { line in
                        TelemetryRow(line: line, threat: threat, themeColor: themeColor)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.25))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeColor.opacity(0.3), lineWidth: 1)
                )
                .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 15)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [themeColor.opacity(0.2), themeColor.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func isTelemetryLine(_ line: String) -> Bool {
        let prefixes = [
            "Відстань до цілі:",
            "Кількість цілей:",
            "Напрямок запуску:",
            "Тип:",
            "Швидкість руху:",
            "Висота польоту:",
            "Очікуваний час:",
            "Відстань:",
            "Історичний маршрут підтверджено",
            "Патерн підтверджений аналітикою"
        ]
        return prefixes.contains(where: { line.hasPrefix($0) })
    }
}
