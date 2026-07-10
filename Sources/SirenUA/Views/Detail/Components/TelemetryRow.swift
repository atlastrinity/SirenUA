import SwiftUI

struct TelemetryRow: View {
    let line: String
    let threat: SingleThreatInfo?
    let themeColor: Color

    var body: some View {
        if let (label, value) = parseTelemetryLine(line) {
            let displayValue: String = {
                if label == "Очікуваний час", let dynamic = threat?.dynamicETA {
                    return dynamic
                }
                if (label == "Відстань" || label == "Відстань до цілі"), let threat = threat {
                    let dynLine = threat.dynamicDistance(from: line)
                    if let (_, val) = parseTelemetryLine(dynLine) {
                        return val
                    }
                }
                return value
            }()
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label + ":")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                Text(displayValue)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(themeColor)
            }
        } else {
            Text(line)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(themeColor)
        }
    }

    private func parseTelemetryLine(_ line: String) -> (String, String)? {
        let prefixes = [
            "Відстань до цілі",
            "Кількість цілей",
            "Напрямок запуску",
            "Тип",
            "Швидкість руху",
            "Висота польоту",
            "Очікуваний час",
            "Відстань"
        ]
        
        for prefix in prefixes {
            if line.hasPrefix(prefix + ":") {
                let value = line.replacingOccurrences(of: prefix + ":", with: "").trimmingCharacters(in: .whitespaces)
                return (prefix, value)
            }
        }
        return nil
    }
}
