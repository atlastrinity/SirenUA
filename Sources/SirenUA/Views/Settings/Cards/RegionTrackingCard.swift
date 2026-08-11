import SwiftUI

struct RegionTrackingCard: View {
    @ObservedObject var settings: NotificationSettings
    @Binding var isRegionsExpanded: Bool
    let onHaptic: (UIImpactFeedbackGenerator.FeedbackStyle) -> Void

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
                        settings.trackedRegionsString = newVal ? allRegionsList.joined(separator: ";") : ""
                    }
                )
            )

            if !settings.allRegionsTracked {
                StyledDivider()
                regionsPickerSection
            }
        }
    }

    private var regionsPickerSection: some View {
        VStack(spacing: 0) {
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
                    let count = settings.trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }.count
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
                                get: { settings.isTracked(region) },
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
