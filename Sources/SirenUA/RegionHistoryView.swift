import SwiftUI
import OSLog
import StoreKit

private let historyLogger = Logger(subsystem: "com.sirenua", category: "RegionHistory")

/// Premium timeline view showing chronological threat events for a specific region
struct RegionHistoryView: View {
    let regionName: String
    let themeColor: Color
    
    @State private var events: [RegionHistoryEvent] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreKitManager
    
    private let networkManager = NetworkManager()
    private let serverURL = "https://sirenua-threatserver.onrender.com"
    
    private var isPremium: Bool {
        UserDefaults.standard.object(forKey: "premiumEnabled") as? Bool ?? false
    }
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
    
    private var displayDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "uk_UA")
        f.dateFormat = "d MMMM yyyy"
        return f
    }
    
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
            
            if !isPremium {
                premiumLockedView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        headerSection
                            .padding(.bottom, 16)
                        
                        // Date picker bar
                        datePickerBar
                            .padding(.bottom, 20)
                        
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
            if isPremium {
                await loadHistory()
            }
        }
    }
    
    // MARK: - Premium Locked View
    
    private var premiumLockedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Хронологія подій\nдоступна з Premium")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            Text("Переглядайте повну історію загроз, аналітику руху та хронологію подій для кожної області.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)
            
            Button(action: {
                Task {
                    if let product = storeManager.storeProducts.first(where: { $0.id.contains("monthly") }) ?? storeManager.storeProducts.first {
                        try? await storeManager.purchase(product)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16))
                    Text("Підключити Premium")
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.black)
                .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Date Picker Bar
    
    private var datePickerBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Previous day
                Button(action: {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    Task { await loadHistory() }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(themeColor)
                        .frame(width: 36, height: 36)
                        .background(themeColor.opacity(0.12))
                        .clipShape(Circle())
                }
                
                // Date display / picker toggle
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showDatePicker.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(themeColor)
                        
                        Text(isToday(selectedDate) ? "Сьогодні" : displayDateFormatter.string(from: selectedDate))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(themeColor.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Next day (disabled if today)
                Button(action: {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    Task { await loadHistory() }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isToday(selectedDate) ? .white.opacity(0.2) : themeColor)
                        .frame(width: 36, height: 36)
                        .background(isToday(selectedDate) ? Color.white.opacity(0.05) : themeColor.opacity(0.12))
                        .clipShape(Circle())
                }
                .disabled(isToday(selectedDate))
                
                Spacer()
                
                // Today button
                if !isToday(selectedDate) {
                    Button(action: {
                        selectedDate = Date()
                        Task { await loadHistory() }
                    }) {
                        Text("Сьогодні")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(themeColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Inline date picker
            if showDatePicker {
                DatePicker(
                    "Оберіть дату",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(themeColor)
                .environment(\.locale, Locale(identifier: "uk_UA"))
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeColor.opacity(0.15), lineWidth: 1)
                )
                .onChange(of: selectedDate) { oldValue, newValue in
                    showDatePicker = false
                    Task { await loadHistory() }
                }
            }
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
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<events.count, id: \.self) { index in
                let event = events[index]
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
                        if index < events.count - 1 {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [levelColor(event.threat_level).opacity(0.3), levelColor(events[index + 1].threat_level).opacity(0.3)],
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
                        .padding(.bottom, index < events.count - 1 ? 12 : 0)
                }
            }
        }
    }
    
    // MARK: - Event Card
    
    private func eventCard(_ event: RegionHistoryEvent) -> some View {
        HStack(alignment: .center, spacing: 14) {
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
        }
        .padding(14)
        .background(.ultraThinMaterial)
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
                .progressViewStyle(CircularProgressViewStyle(tint: themeColor))
                .scaleEffect(1.2)
            
            Text("Завантаження подій...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Спробувати знову") {
                Task { await loadHistory() }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(themeColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.08))
                    .frame(width: 70, height: 70)
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(themeColor.opacity(0.5))
            }
            
            Text("Подій не зафіксовано")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            
            Text("За \(isToday(selectedDate) ? "сьогодні" : displayDateFormatter.string(from: selectedDate))\nподій для цієї області не було")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: - Helpers
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
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
    
    // MARK: - Data Loading
    
    private func loadHistory() async {
        isLoading = true
        errorMessage = nil
        
        let dateString = dateFormatter.string(from: selectedDate)
        
        do {
            let fetched = try await networkManager.fetchRegionHistory(
                serverURL: serverURL,
                region: regionName,
                date: dateString,
                limit: 200
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
