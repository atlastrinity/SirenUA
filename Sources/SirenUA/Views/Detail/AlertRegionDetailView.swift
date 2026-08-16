import SwiftUI
import MapKit
import OSLog

struct AlertRegionDetailView: View {
    let region: AlertRegion
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreKitManager
    @EnvironmentObject private var viewModel: AlertViewModelV3
    @State private var isConfirmed = false
    @State private var isPulsing = false
    @State private var selectedThreatIndex: Int = 0
    @State private var timeRefreshTrigger = Date()
    private let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    private var liveRegion: AlertRegion {
        viewModel.alerts.first(where: { $0.name == region.name || $0.id == region.id }) ?? region
    }
    
    private var isPremium: Bool {
        PremiumGatekeeper.shared.canAccess(.threatDetails)
    }

    private var hasAnyThreat: Bool {
        return liveRegion.threatLevel != nil || !liveRegion.activeThreats.isEmpty || liveRegion.isThreatPredictive || (liveRegion.threatDetail != nil && !liveRegion.threatDetail!.isEmpty)
    }

    private var isThreatActive: Bool {
        !liveRegion.isActive && hasAnyThreat
    }
    
    private var selectedThreat: SingleThreatInfo? {
        if !liveRegion.activeThreats.isEmpty {
            let idx = min(selectedThreatIndex, liveRegion.activeThreats.count - 1)
            return liveRegion.activeThreats[idx]
        }
        if let level = liveRegion.threatLevel {
            return SingleThreatInfo(
                threat_id: "region_\(liveRegion.id)",
                level: level,
                type: liveRegion.threatType,
                detail: effectiveThreatDetail,
                confidence: liveRegion.threatConfidence,
                eta: liveRegion.threatETA,
                is_predictive: liveRegion.isThreatPredictive
            )
        }
        return nil
    }
    
    private func getThreatDescription(_ type: String?) -> String {
        return ThreatConstants.title(for: type)
    }

    private var effectiveThreatDetail: String? {
        if let d = selectedThreat?.detail, !d.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return d
        }
        if let d = liveRegion.threatDetail, !d.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return d
        }
        if let t = selectedThreat?.type ?? liveRegion.threatType {
            let desc = getThreatDescription(t)
            var msg = "⚠️ Фіксується загроза (\(desc))."
            if let eta = selectedThreat?.eta ?? liveRegion.displayETA, !eta.isEmpty {
                msg += " Час підльоту: \(eta)."
            }
            return msg
        }
        if liveRegion.isThreatPredictive {
            var msg = "⚠️ Зафіксовано потенційний рух цілі в напрямку області."
            if let eta = liveRegion.displayETA, !eta.isEmpty {
                msg += " Час підльоту: \(eta)."
            }
            return msg
        }
        return nil
    }

    private var statusTitle: String {
        if liveRegion.isActive {
            return "АКТИВНА ТРИВОГА"
        } else if hasAnyThreat {
            return "Є ЗАГРОЗА (ПІДЛІТ / ТРАНЗИТ)"
        } else {
            return "ТРИВОГУ СКАСОВАНО"
        }
    }
    
    private var themeColor: Color {
        if liveRegion.isActive {
            return .red
        } else if isThreatActive {
            return liveRegion.color
        } else {
            return .green
        }
    }
    
    private var threatTypeEmoji: String {
        return ThreatConstants.emoji(for: liveRegion.threatType)
    }

    var body: some View {
        ZStack {
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
                            let _ = timeRefreshTrigger
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

                    // Region name card
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

                    // Multi-threat selector (Premium only)
                    if isPremium && region.activeThreats.count > 1 {
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
                                        ThreatMiniCard(
                                            threat: threat,
                                            isSelected: isSelected,
                                            themeColor: themeColor,
                                            timeRefreshTrigger: timeRefreshTrigger
                                        )
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
                            let displayLevel = selectedThreat?.level.uppercased() ?? liveRegion.threatLevel?.uppercased() ?? "LOW"
                            Text(isThreatActive ? "Загроза: \(displayLevel)" : "Рівень \(liveRegion.level)")
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

                    // Card 1: Що відомо про загрозу (Premium only)
                    if isPremium, let detail = effectiveThreatDetail, !detail.isEmpty {
                        ThreatDetailCard(
                            detail: detail,
                            threat: selectedThreat,
                            themeColor: themeColor,
                            timeRefreshTrigger: timeRefreshTrigger
                        )
                    } else if !isPremium && (effectiveThreatDetail != nil || isThreatActive) {
                        PremiumPurchaseCTA(
                            storeManager: storeManager,
                            title: "Оперативна деталізація загрози та аналітика ШІ доступні з Premium підпискою",
                            feature: .threatDetails
                        )
                    } else if liveRegion.isActive {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundStyle(themeColor)
                                    .font(.system(size: 14))
                                Text("Інформація про тривогу")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Text("У регіоні \(liveRegion.name) оголошено офіційну повітряну тривогу. AI-моніторинг обробляє оперативні джерела та вектори загроз.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineSpacing(4)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(themeColor.opacity(0.2), lineWidth: 1)
                        )
                    } else if isThreatActive {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .foregroundStyle(themeColor)
                                    .font(.system(size: 14))
                                Text("Інформація про загрозу")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Text("У регіоні \(liveRegion.name) виявлено підвищений рівень загрози. Будьте уважні та слідкуйте за оновленнями.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineSpacing(4)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(themeColor.opacity(0.2), lineWidth: 1)
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundStyle(themeColor)
                                    .font(.system(size: 14))
                                Text("Статус області")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Text("У регіоні \(liveRegion.name) активні повітряні тривоги та загрози відсутні. Обстановка спокійна.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineSpacing(4)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(themeColor.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // Card 2: Імовірність загрози (Premium only)
                    if isPremium, let confidence = selectedThreat?.confidence ?? liveRegion.threatConfidence {
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

                    // Chronology Navigation Link
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
                                textChronologyLabel()
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

                    // Warning card
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
            if RegionRegistry.isPermanentlyActive(region.name) {
                dismiss()
                return
            }
            selectedThreatIndex = max(0, liveRegion.activeThreats.count - 1)
        }
        .onChange(of: liveRegion.activeThreats) { oldValue, newValue in
            selectedThreatIndex = max(0, newValue.count - 1)
        }
        .onReceive(refreshTimer) { _ in
            timeRefreshTrigger = Date()
        }
        } // ZStack
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

    @ViewBuilder
    private func textChronologyLabel() -> some View {
        Text("Хронологія подій")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
        Text("Переглянути історію загроз")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.4))
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
