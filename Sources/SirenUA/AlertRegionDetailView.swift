import SwiftUI
import MapKit
import OSLog

struct AlertRegionDetailView: View {
    let region: AlertRegion
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreKitManager
    @State private var isConfirmed = false
    @State private var isPulsing = false
    @State private var selectedThreatIndex: Int = 0
    @State private var timeRefreshTrigger = Date()
    private let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    private var isPremium: Bool {
        storeManager.isPremium
    }
    private var isThreatActive: Bool {
        !region.isActive && region.threatLevel != nil
    }
    
    /// Поточна вибрана загроза (або nil якщо немає)
    private var selectedThreat: SingleThreatInfo? {
        guard !region.activeThreats.isEmpty else { return nil }
        let idx = min(selectedThreatIndex, region.activeThreats.count - 1)
        return region.activeThreats[idx]
    }
    
    private var statusTitle: String {
        if region.isActive {
            return "АКТИВНА ТРИВОГА"
        } else if isThreatActive {
            return "Є ЗАГРОЗА (PREMIUM)"
        } else {
            return "ТРИВОГУ СКАСОВАНО"
        }
    }
    
    private var themeColor: Color {
        if region.isActive {
            return .red
        } else if isThreatActive {
            return .yellow
        } else {
            return .green
        }
    }
    
    /// Emoji icon for the current threat type
    private var threatTypeEmoji: String {
        switch region.threatType {
        case "shahed": return "🛩"
        case "cruise_missile": return "🚀"
        case "ballistic": return "💥"
        case "mig31k": return "✈️"
        case "kab": return "💣"
        case "iskander": return "🎯"
        case "tu95": return "✈️"
        default: return "⚠️"
        }
    }

    var body: some View {
        ZStack {
            // Dark glassmorphism background
            Color(red: 0.06, green: 0.06, blue: 0.10)
                .ignoresSafeArea()

            RadialGradient(
                colors: [themeColor.opacity(0.08), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header status card
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(themeColor.opacity(0.15))
                                .frame(width: 46, height: 46)
                                .scaleEffect(isPulsing && (region.isActive || isThreatActive) ? 1.15 : 1.0)
                                .opacity(isPulsing && (region.isActive || isThreatActive) ? 0.6 : 1.0)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
                            Image(systemName: region.isActive ? "exclamationmark.triangle.fill" : (isThreatActive ? "bell.badge.fill" : "checkmark.circle.fill"))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(themeColor)
                        }
                        .shadow(color: themeColor.opacity(0.4), radius: 8)
                        .onAppear { isPulsing = true }

                        VStack(alignment: .leading, spacing: 3) {
                            let _ = timeRefreshTrigger // Force refresh on timer tick
                            Text(statusTitle)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(themeColor)

                            if let threatTime = selectedThreat?.formattedSince {
                                Text("Виявлено: \(threatTime)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.45))
                            } else if let changed = region.lastChanged {
                                Text(changed)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(.ultraThinMaterial)
                    .background(themeColor.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    colors: [themeColor.opacity(0.4), themeColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: themeColor.opacity(0.15), radius: 12)

                    // Region name with glassmorphism
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(themeColor)
                                .font(.system(size: 14))
                            Text("Область")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Text(region.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(themeColor)
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
                                    colors: [themeColor.opacity(0.25), themeColor.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                    // ── Multi-threat selector (shows only if 2+ active threats) ──
                    if region.activeThreats.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "list.bullet.rectangle.fill")
                                    .foregroundStyle(themeColor)
                                    .font(.system(size: 14))
                                Text("Активні загрози (\(region.activeThreats.count))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 4)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Array(region.activeThreats.enumerated()), id: \.element.id) { idx, threat in
                                        let isSelected = (idx == selectedThreatIndex)
                                        threatMiniCard(threat: threat, isSelected: isSelected)
                                            .onTapGesture {
                                                withAnimation(.easeInOut(duration: 0.25)) {
                                                    selectedThreatIndex = idx
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
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

                    // Alert/Threat level badge
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(themeColor)
                                .font(.system(size: 14))
                            Text(isThreatActive ? "Рівень загрози" : "Рівень тривоги")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            if isThreatActive {
                                Text(threatTypeEmoji)
                                    .font(.system(size: 18))
                            }
                            let displayLevel = selectedThreat?.level.uppercased() ?? region.threatLevel?.uppercased() ?? "LOW"
                            Text(isThreatActive ? "Загроза: \(displayLevel)" : "Рівень \(region.level)")
                                .font(.system(size: 16, weight: .bold))
                        }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(themeColor.opacity(0.12))
                            .foregroundStyle(themeColor)
                            .cornerRadius(12)
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

                    // Card 1: Що відомо (Premium-only) or Purchase CTA
                    // Uses selected threat's detail if available, falls back to region's legacy threatDetail
                    if let detail = selectedThreat?.detail ?? region.threatDetail, !detail.isEmpty {
                        if isPremium {
                            threatDetailCard(detail: detail)
                        } else {
                            premiumPurchaseCTA()
                        }
                    }
                    
                    // Card 2: Імовірність загрози (Premium only)
                    // Uses selected threat's confidence if available
                    if isPremium, let confidence = selectedThreat?.confidence ?? region.threatConfidence {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "shield.checkered")
                                    .foregroundStyle(themeColor)
                                    .font(.system(size: 14))
                                Text("Ймовірність загрози")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 20) {
                                // Circular confidence ring
                                ZStack {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                                        .frame(width: 70, height: 70)
                                    
                                    Circle()
                                        .trim(from: 0, to: CGFloat(confidence) / 100.0)
                                        .stroke(
                                            confidenceColor(confidence),
                                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                        )
                                        .frame(width: 70, height: 70)
                                        .rotationEffect(.degrees(-90))
                                    
                                    VStack(spacing: 1) {
                                        Text("\(confidence)%")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundStyle(confidenceColor(confidence))
                                        Text("довіра")
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(confidenceLabel(confidence))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(confidenceColor(confidence))
                                    
                                    Text("Оцінка ймовірності небезпеки на основі підтверджених векторів руху.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.6))
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
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
                                        colors: [themeColor.opacity(0.3), themeColor.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }

                    // History button (moved above warning)
                    NavigationLink(destination: RegionHistoryView(regionName: region.name, themeColor: themeColor)) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(themeColor.opacity(0.12))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(themeColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Хронологія подій")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("Переглянути історію загроз")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
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
                    .buttonStyle(.plain)

                    // Warning message (moved below chronology)
                    if (region.isActive || isThreatActive) && !isConfirmed {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(themeColor)

                                Text(region.isActive ? "⚠️ Тривога!" : "⚠️ Попередження")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(themeColor)
                            }

                            Text(region.isActive ? 
                                 "У цій області оголошено повітряну тривогу. Негайно прямуйте в укриття!" : 
                                 "Виявлено загрозу початку повітряної тривоги (пуск ракет/рух БПЛА). Будьте готові прослідувати в безпечне місце.")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)

                            // Action buttons for warning
                            HStack(spacing: 12) {
                                Button(action: {
                                    dismiss()
                                }) {
                                    Text(region.isActive ? "Я в безпеці" : "Зрозуміло")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(themeColor)
                                        .foregroundStyle(.black)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding()
                        .background(themeColor.opacity(0.1))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(themeColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding()
            }
            .background(Color.clear)
            .navigationTitle(region.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .onAppear {
            selectedThreatIndex = max(0, region.activeThreats.count - 1)
        }
        .onChange(of: region.activeThreats) { oldValue, newValue in
            selectedThreatIndex = max(0, newValue.count - 1)
        }
        .onReceive(refreshTimer) { _ in
            timeRefreshTrigger = Date()
        }
        } // ZStack
    }

    // MARK: - Extracted Sub-Views
    
    @ViewBuilder
    private func threatDetailCard(detail: String) -> some View {
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
                
                if let threat = selectedThreat, let dynamic = threat.dynamicETA {
                    let _ = timeRefreshTrigger // Force refresh on timer tick
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
            
            if !descriptionLines.isEmpty {
                Text(descriptionLines.joined(separator: "\n"))
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(6)
            }
            
            if !telemetryLines.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(telemetryLines, id: \.self) { line in
                        telemetryRow(line: line)
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
    
    @ViewBuilder
    private func threatMiniCard(threat: SingleThreatInfo, isSelected: Bool) -> some View {
        let _ = timeRefreshTrigger // Force redraw on timer tick
        HStack(spacing: 6) {
            Image(systemName: threat.threatIcon)
                .font(.system(size: 14, weight: .bold))
            Text(threat.threatLabel)
                .font(.system(size: 13, weight: .semibold))
            if let eta = threat.dynamicETA, !eta.isEmpty {
                Text("(\(eta))")
                    .font(.system(size: 11))
                    .opacity(0.7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? themeColor.opacity(0.2) : Color.white.opacity(0.05))
        .foregroundStyle(isSelected ? themeColor : .white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? themeColor : Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func telemetryRow(line: String) -> some View {
        if let (label, value) = parseTelemetryLine(line) {
            let displayValue: String = {
                if label == "Очікуваний час", let dynamic = selectedThreat?.dynamicETA {
                    return dynamic
                }
                if (label == "Відстань" || label == "Відстань до цілі"), let threat = selectedThreat {
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
    
    @ViewBuilder
    private func premiumPurchaseCTA() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Деталі загрози доступні\nлише з Premium підпискою")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            Text("Отримайте доступ до аналітики загроз, телеметрії руху, прогнозів та хронології подій.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            
            Button(action: {
                Task {
                    if let product = storeManager.storeProducts.first(where: { $0.id.contains("monthly") }) ?? storeManager.storeProducts.first {
                        _ = try? await storeManager.purchase(product)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                    Text("Підключити Premium")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.black)
                .cornerRadius(14)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 15)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.yellow.opacity(0.4), .orange.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
    }
    
    private func confidenceColor(_ confidence: Int) -> Color {
        if confidence >= 85 { return .red }
        if confidence >= 60 { return .orange }
        return .yellow
    }
    
    private func confidenceLabel(_ confidence: Int) -> String {
        if confidence >= 85 { return "Висока ймовірність" }
        if confidence >= 60 { return "Ймовірна загроза" }
        return "Можлива загроза"
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


struct AlertRegionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        AlertRegionDetailView(
            region: AlertRegion(
                id: 1,
                name: "Київська область",
                isActive: true,
                level: 4,
                description: "Test alert simulation",
                coordinate: CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)
            )
        )
    }
}
