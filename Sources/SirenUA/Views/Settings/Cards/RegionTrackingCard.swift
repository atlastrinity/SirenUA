import SwiftUI

struct RegionTrackingCard: View {
    @ObservedObject var settings: NotificationSettings
    @Binding var isRegionsExpanded: Bool
    let onHaptic: (UIImpactFeedbackGenerator.FeedbackStyle) -> Void

    @State private var showPaywallSheet: Bool = false

    /// Канонічний список регіонів з єдиного реєстру
    private var allRegionsList: [String] { RegionRegistry.allRegions }

    var body: some View {
        SettingsCard(title: "Відслідковувані регіони", icon: "mappin.and.ellipse", iconColor: ChartColorTheme.active) {
            StyledToggleRow(
                title: "Усі регіони України",
                subtitle: "Отримувати тривоги по всій країні",
                icon: "globe.europe.africa.fill",
                iconColor: ChartColorTheme.active,
                isOn: Binding(
                    get: { settings.allRegionsTracked },
                    set: { newVal in
                        onHaptic(.light)
                        settings.allRegionsTracked = newVal
                        if newVal {
                            settings.trackedRegionsString = allRegionsList.joined(separator: ";")
                        } else {
                            settings.trackedRegionsString = ""
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isRegionsExpanded = true
                            }
                        }
                    }
                )
            )

            if !settings.allRegionsTracked {
                StyledDivider()
                regionsPickerSection
            }

            StyledDivider()

            // Траєкторії для всієї України (Premium)
            PremiumThreatToggleRow(
                title: "Траєкторії для всієї України",
                subtitle: settings.allUkraineTrajectoriesEnabled
                    ? "Відображаються для всіх областей України"
                    : "Відображаються лише для обраних областей",
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                iconColor: .siGold,
                isOn: $settings.allUkraineTrajectoriesEnabled,
                isPremium: PremiumGatekeeper.shared.canAccess(.trajectories),
                onLockedTap: {
                    onHaptic(.medium)
                    showPaywallSheet = true
                }
            )
            .onChange(of: settings.allUkraineTrajectoriesEnabled) { _, _ in onHaptic(.light) }
        }
        .sheet(isPresented: $showPaywallSheet) {
            PremiumPaywallSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var regionsPickerSection: some View {
        let trackedList = settings.trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }
        let trackedSet = Set(trackedList)
        let count = trackedList.count

        return VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isRegionsExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: isRegionsExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(.siGold)
                        .font(.system(size: 16))
                    Text("Вибрати регіони вручну")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                    Spacer()
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.siGold)
                            .clipShape(Capsule())
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isRegionsExpanded {
                VStack(spacing: 0) {
                    ForEach(allRegionsList, id: \.self) { region in
                        HStack {
                            Text(region)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { trackedSet.contains(region) },
                                set: { isOn in
                                    onHaptic(.light)
                                    settings.setTracked(region, isOn: isOn)
                                }
                            ))
                            .labelsHidden()
                            .tint(.siGold)
                        }
                        .padding(.vertical, 9)
                        .padding(.horizontal, 4)

                        if region != allRegionsList.last {
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
