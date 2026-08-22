import SwiftUI

struct RegionTrackingCard: View {
    @ObservedObject var settings: NotificationSettings
    @Binding var isRegionsExpanded: Bool
    let onHaptic: (UIImpactFeedbackGenerator.FeedbackStyle) -> Void

    @State private var showRegionPickerSheet: Bool = false
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
        .sheet(isPresented: $showRegionPickerSheet) {
            RegionSelectionSheet(
                allRegionsTracked: $settings.allRegionsTracked,
                trackedRegionsString: $settings.trackedRegionsString,
                onConfirm: {
                    NotificationManager.shared.syncTopicSubscriptions()
                }
            )
        }
    }

    private var regionsPickerSection: some View {
        let trackedList = settings.trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }
        let count = trackedList.count

        return VStack(spacing: 8) {
            // Кнопка відкриття повноцінного модального вікна вибору районів
            Button(action: {
                onHaptic(.light)
                showRegionPickerSheet = true
            }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.siGold)
                        .font(.system(size: 15))
                    Text("Налаштувати області та райони...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    if count > 0 {
                        Text("\(count) обл.")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.siGold)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Швидкий список областей
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isRegionsExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: isRegionsExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 15))
                    Text(isRegionsExpanded ? "Приховати список" : "Швидкий список областей")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isRegionsExpanded {
                VStack(spacing: 0) {
                    ForEach(allRegionsList, id: \.self) { region in
                        let isFullySelected = settings.isRegionFullySelected(region)
                        let selectedDistricts = settings.selectedDistricts(for: region)
                        let allDistricts = DistrictRegistry.districts(for: region)
                        let isPartiallySelected = !isFullySelected && !selectedDistricts.isEmpty

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(region)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)

                                if !allDistricts.isEmpty && region != "м. Київ" {
                                    if isFullySelected {
                                        Text("Уся область (\(allDistricts.count) районів)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.siGold.opacity(0.8))
                                    } else if isPartiallySelected {
                                        Text("Обрано \(selectedDistricts.count) з \(allDistricts.count) районів")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color.orange)
                                    }
                                }
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { isFullySelected || isPartiallySelected },
                                set: { isOn in
                                    onHaptic(.light)
                                    settings.setTracked(region, isOn: isOn)
                                }
                            ))
                            .labelsHidden()
                            .tint(.siGold)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)

                        if region != allRegionsList.last {
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
