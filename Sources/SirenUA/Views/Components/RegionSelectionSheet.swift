import SwiftUI

struct RegionSelectionSheet: View {
    @Binding var allRegionsTracked: Bool
    @Binding var trackedRegionsString: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var localAllTracked: Bool = true
    @State private var localSelectedSet: Set<String> = []
    @State private var searchText: String = ""

    private let allRegionsList = [
        "Вінницька область",    "Волинська область",       "Дніпропетровська область",
        "Донецька область",     "Житомирська область",     "Закарпатська область",
        "Запорізька область",   "Івано-Франківська область","Київська область",
        "м. Київ",              "Кіровоградська область",  "Луганська область",
        "Львівська область",    "Миколаївська область",    "Одеська область",
        "Полтавська область",   "Рівненська область",      "Сумська область",
        "Тернопільська область","Харківська область",      "Херсонська область",
        "Хмельницька область",  "Черкаська область",       "Чернівецька область",
        "Чернігівська область"
    ]

    private var themeColor: Color {
        Color(red: 0.20, green: 0.52, blue: 0.98) // siBlue
    }

    private var filteredRegions: [String] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return allRegionsList
        } else {
            return allRegionsList.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.07, blue: 0.12)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.4))
                            .font(.system(size: 15))
                        
                        TextField("Пошук області...", text: $searchText)
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .medium))
                            .disableAutocorrection(true)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.4))
                                    .font(.system(size: 15))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    // Track All Option Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            localAllTracked.toggle()
                            if localAllTracked {
                                localSelectedSet = Set(allRegionsList)
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(localAllTracked ? themeColor.opacity(0.2) : Color.white.opacity(0.05))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "globe.europe.africa.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(localAllTracked ? themeColor : .white.opacity(0.6))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("🌐 Усі області України")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Отримувати сповіщення по всій території")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            Spacer()

                            Image(systemName: localAllTracked ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(localAllTracked ? themeColor : .white.opacity(0.25))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(localAllTracked ? themeColor.opacity(0.12) : Color.white.opacity(0.04))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(localAllTracked ? themeColor.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 8)

                    // Regions Checklist ScrollView
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(filteredRegions, id: \.self) { regionName in
                                let isSelected = localAllTracked || localSelectedSet.contains(regionName)

                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        if localAllTracked {
                                            localAllTracked = false
                                            localSelectedSet = [regionName]
                                        } else {
                                            if localSelectedSet.contains(regionName) {
                                                localSelectedSet.remove(regionName)
                                            } else {
                                                localSelectedSet.insert(regionName)
                                            }
                                        }
                                        if localSelectedSet.count == allRegionsList.count {
                                            localAllTracked = true
                                        }
                                    }
                                }) {
                                    HStack {
                                        Text(regionName)
                                            .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                            .foregroundColor(isSelected ? .white : .white.opacity(0.75))

                                        Spacer()

                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(isSelected ? themeColor : .white.opacity(0.2))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? themeColor.opacity(0.08) : Color.white.opacity(0.03))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? themeColor.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }

                    // Bottom OK / Confirm Action Button
                    VStack(spacing: 4) {
                        Button(action: {
                            saveAndConfirm()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("ОК • Підтвердити вибір (\(localAllTracked ? "Усі області" : "\(localSelectedSet.count)"))")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [themeColor, themeColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: themeColor.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.07, green: 0.09, blue: 0.15))
                }
            }
            .navigationTitle("Вибір областей")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
            .onAppear {
                localAllTracked = allRegionsTracked
                let list = trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }
                if localAllTracked || list.isEmpty {
                    localSelectedSet = Set(allRegionsList)
                } else {
                    localSelectedSet = Set(list)
                }
            }
        }
    }

    private func saveAndConfirm() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if localAllTracked || localSelectedSet.isEmpty || localSelectedSet.count == allRegionsList.count {
            allRegionsTracked = true
            trackedRegionsString = allRegionsList.joined(separator: ";")
        } else {
            allRegionsTracked = false
            trackedRegionsString = Array(localSelectedSet).joined(separator: ";")
        }
        onConfirm()
        dismiss()
    }
}
