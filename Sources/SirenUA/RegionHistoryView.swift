import SwiftUI
import OSLog

private let historyLogger = Logger(subsystem: "com.sirenua", category: "RegionHistory")

/// Premium timeline view showing chronological threat events for a specific region
@available(iOS 16.0, *)
struct RegionHistoryView: View {
    let regionName: String
    let themeColor: Color
    
    @State private var events: [RegionHistoryEvent] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    private let networkManager = NetworkManager()
    private let serverURL = "https://sirenua-threatserver.onrender.com"
    
    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.05, green: 0.05, blue: 0.09)
                .ignoresSafeArea()
            
            // Subtle radial glow
            RadialGradient(
                colors: [themeColor.opacity(0.06), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 350
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    headerSection
                        .padding(.bottom, 24)
                    
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if events.isEmpty {
                        emptyView
                    } else {
                        timelineContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Хронологія")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await loadHistory()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(themeColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Хронологія подій")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(regionName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                if !events.isEmpty {
                    Text("\(events.count)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(themeColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [themeColor.opacity(0.3), themeColor.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }
    
    // MARK: - Timeline content
    
    private var timelineContent: some View {
        let grouped = Dictionary(grouping: events) { $0.displayDay }
        let sortedDays = grouped.keys.sorted { a, b in
            // Sort by the first event's timestamp in each group (descending)
            let aTime = grouped[a]?.first?.timestamp ?? ""
            let bTime = grouped[b]?.first?.timestamp ?? ""
            return aTime > bTime
        }
        
        return VStack(alignment: .leading, spacing: 24) {
            ForEach(sortedDays, id: \.self) { day in
                // Day header
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(day)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(height: 1)
                }
                .padding(.bottom, 4)
                
                // Timeline events for this day
                let dayEvents = grouped[day] ?? []
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(dayEvents.enumerated()), id: \.element.id) { index, event in
                        HStack(alignment: .top, spacing: 14) {
                            // Timeline spine
                            VStack(spacing: 0) {
                                // Dot
                                ZStack {
                                    Circle()
                                        .fill(levelColor(event.threat_level).opacity(0.2))
                                        .frame(width: 28, height: 28)
                                    Circle()
                                        .fill(levelColor(event.threat_level))
                                        .frame(width: 12, height: 12)
                                }
                                
                                // Connecting line (not for last item)
                                if index < dayEvents.count - 1 {
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [levelColor(event.threat_level).opacity(0.3), levelColor(dayEvents[index + 1].threat_level).opacity(0.3)],
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
                                .padding(.bottom, index < dayEvents.count - 1 ? 12 : 0)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Event Card
    
    private func eventCard(_ event: RegionHistoryEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: type icon + name + time
            HStack(spacing: 8) {
                Text(event.typeIcon)
                    .font(.system(size: 16))
                
                Text(event.typeName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(levelColor(event.threat_level))
                
                Spacer()
                
                Text(event.displayTime)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            
            // Detail text
            if let detail = event.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Bottom badges
            HStack(spacing: 8) {
                // Level badge
                Text(levelLabel(event.threat_level).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(levelColor(event.threat_level))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(levelColor(event.threat_level).opacity(0.12))
                    .clipShape(Capsule())
                
                // Confidence badge
                if let conf = event.confidence {
                    HStack(spacing: 3) {
                        Image(systemName: "cpu")
                            .font(.system(size: 8))
                        Text("\(conf)%")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.06))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .background(levelColor(event.threat_level).opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(levelColor(event.threat_level).opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - States
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(themeColor)
                .scaleEffect(1.2)
            Text("Завантаження хронології...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            Text("Помилка завантаження")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
            
            Button("Спробувати ще") {
                Task { await loadHistory() }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(themeColor)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 34))
                    .foregroundStyle(themeColor.opacity(0.5))
            }
            
            Text("Подій не зафіксовано")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            
            Text("Хронологія загроз для цієї області\nпоки що порожня")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: - Helpers
    
    private func levelColor(_ level: String) -> Color {
        switch level {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return Color(red: 0.4, green: 0.8, blue: 1.0)
        default: return .gray
        }
    }
    
    private func levelLabel(_ level: String) -> String {
        switch level {
        case "critical": return "Критичний"
        case "high": return "Високий"
        case "medium": return "Середній"
        case "low": return "Низький"
        default: return level
        }
    }
    
    // MARK: - Data Loading
    
    private func loadHistory() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetched = try await networkManager.fetchRegionHistory(
                serverURL: serverURL,
                region: regionName,
                limit: 100
            )
            await MainActor.run {
                events = fetched
                isLoading = false
            }
        } catch {
            historyLogger.error("Failed to load history for \(regionName): \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
