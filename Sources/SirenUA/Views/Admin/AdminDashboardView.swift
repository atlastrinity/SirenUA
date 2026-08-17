import SwiftUI

struct AdminDashboardView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AdminViewModel()
    
    // Custom Horizontal Scrollable Navigation Tabs
    @State private var selectedTab = 0
    private let tabs = [
        "Дашборд",
        "Палантір AI",
        "Кореляція AI",
        "Хронологія",
        "AI Правила",
        "Помилки",
        "Керування"
    ]

    private let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                ChartColorTheme.bg.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerView
                    tabSelectorView
                    Divider().background(Color.white.opacity(0.1))

                    if let err = viewModel.lastFetchError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text(err)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Button("Повторити") {
                                Task { await viewModel.refreshCurrentTab(selectedTab: selectedTab) }
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.25))
                    }
                    
                    if viewModel.isLoading && viewModel.dashboardStats == nil && viewModel.correlationV2Data == nil && viewModel.palantirOverview == nil {
                        Spacer()
                        ProgressView("Завантаження даних...")
                            .tint(.white)
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                switch selectedTab {
                                case 0:
                                    AdminDashboardTab(viewModel: viewModel)
                                case 1:
                                    AdminPalantirTab(viewModel: viewModel)
                                case 2:
                                    AdminCorrelationTab(viewModel: viewModel)
                                case 3:
                                    AdminChronologyTab(viewModel: viewModel)
                                case 4:
                                    AdminRulesTab(viewModel: viewModel)
                                case 5:
                                    AdminErrorsTab(viewModel: viewModel)
                                default:
                                    AdminControlTab(viewModel: viewModel)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                            .padding(.bottom, 32)
                        }
                        .refreshable {
                            await viewModel.refreshCurrentTab(selectedTab: selectedTab)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .task {
                async let _ = viewModel.loadRegions()
                await viewModel.refreshCurrentTab(selectedTab: selectedTab)
            }
            .onReceive(refreshTimer) { _ in
                Task {
                    await viewModel.refreshCurrentTab(selectedTab: selectedTab)
                }
            }
            .onChange(of: selectedTab) { _, newTab in
                Task { await viewModel.refreshCurrentTab(selectedTab: newTab) }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("🚨 SirenUA Console")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .shadow(color: .green, radius: 4)
                    Text("Нативний iOS моніторинг")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
            HStack(spacing: 8) {
                Button(action: {
                    viewModel.triggerHaptic("medium")
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 12))
                        Text("Користувач")
                            .font(.system(size: 13, weight: .semibold))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }

                Button(action: {
                    viewModel.triggerHaptic()
                    dismiss()
                }) {
                    Text("Готово")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.blue.opacity(0.3))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ChartColorTheme.cardBg)
    }
    
    // MARK: - Tab Selector Bar
    
    private var tabSelectorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<tabs.count, id: \.self) { idx in
                    Button(action: {
                        viewModel.triggerHaptic("light")
                        selectedTab = idx
                    }) {
                        Text(tabs[idx])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selectedTab == idx ? .white : .white.opacity(0.55))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedTab == idx ? Color.blue.opacity(0.3) : Color.white.opacity(0.04)
                            )
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(selectedTab == idx ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(ChartColorTheme.bg)
    }
}
