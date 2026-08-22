import SwiftUI

struct RegionSelectionSheet: View {
    @Binding var allRegionsTracked: Bool
    @Binding var trackedRegionsString: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var localAllTracked: Bool = true
    /// Мапа вибору: ключ — область, значення: nil (вся область) або Set<String> (список вибраних районів)
    @State private var localSelectionMap: [String: Set<String>?] = [:]
    @State private var expandedRegions: Set<String> = []
    @State private var searchText: String = ""

    /// Канонічний список регіонів з єдиного реєстру
    private var allRegionsList: [String] { RegionRegistry.allRegions }

    private var themeColor: Color {
        Color(red: 0.20, green: 0.52, blue: 0.98) // siBlue
    }

    private var filteredRegions: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return allRegionsList
        }
        return allRegionsList.filter { region in
            if region.lowercased().contains(query) { return true }
            let districts = DistrictRegistry.districts(for: region)
            return districts.contains { $0.lowercased().contains(query) }
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

                        TextField("Пошук області або району...", text: $searchText)
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .medium))
                            .disableAutocorrection(true)
                            .onChange(of: searchText) { _, newValue in
                                let query = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                if !query.isEmpty {
                                    // Автоматично розгортаємо області, що містять знайдені райони
                                    var autoExpand: Set<String> = []
                                    for r in allRegionsList {
                                        let dists = DistrictRegistry.districts(for: r)
                                        if dists.contains(where: { $0.lowercased().contains(query) }) {
                                            autoExpand.insert(r)
                                        }
                                    }
                                    expandedRegions.formUnion(autoExpand)
                                }
                            }

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
                                localSelectionMap.removeAll()
                                for r in allRegionsList {
                                    localSelectionMap[r] = nil
                                }
                            } else {
                                localSelectionMap.removeAll()
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

                    // Regions Checklist ScrollView with Accordion District Dropdowns
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredRegions, id: \.self) { regionName in
                                regionCard(regionName: regionName)
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
                                Text("ОК • Підтвердити вибір (\(selectionSummaryTitle))")
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
            .navigationTitle("Вибір областей та районів")
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
                loadInitialState()
            }
        }
    }

    // MARK: - Region Card Component with Accordion
    @ViewBuilder
    private func regionCard(regionName: String) -> some View {
        let districts = DistrictRegistry.districts(for: regionName)
        let hasDistricts = !districts.isEmpty && regionName != "м. Київ"
        let isExpanded = expandedRegions.contains(regionName)

        let isRegionActive: Bool = {
            if localAllTracked { return true }
            return localSelectionMap.keys.contains(regionName)
        }()

        let isWholeSelected: Bool = {
            if localAllTracked { return true }
            guard let entry = localSelectionMap[regionName] else { return false }
            return entry == nil || (entry?.count == districts.count)
        }()

        let selectedDistrictCount: Int = {
            if localAllTracked { return districts.count }
            guard let entry = localSelectionMap[regionName] else { return 0 }
            return entry?.count ?? districts.count
        }()

        VStack(spacing: 0) {
            // Main Oblast Row
            HStack(spacing: 10) {
                // Expand / Collapse Chevron Button (якщо є райони)
                if hasDistricts {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            if isExpanded {
                                expandedRegions.remove(regionName)
                            } else {
                                expandedRegions.insert(regionName)
                            }
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 24)
                }

                // Region Name & District Counter Badge
                VStack(alignment: .leading, spacing: 2) {
                    Text(regionName)
                        .font(.system(size: 14, weight: isRegionActive ? .bold : .medium))
                        .foregroundColor(isRegionActive ? .white : .white.opacity(0.75))

                    if hasDistricts {
                        if isWholeSelected {
                            Text("Уся область (\(districts.count) районів)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(themeColor.opacity(0.85))
                        } else if selectedDistrictCount > 0 {
                            Text("Обрано \(selectedDistrictCount) з \(districts.count) районів")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.orange.opacity(0.9))
                        } else {
                            Text("\(districts.count) районів")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                }

                Spacer()

                // Whole Region Selection Button (Toggle all districts)
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        toggleWholeRegion(regionName: regionName, allDistricts: districts)
                    }
                }) {
                    Image(systemName: isWholeSelected ? "checkmark.circle.fill" : (selectedDistrictCount > 0 ? "minus.circle.fill" : "circle"))
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(isWholeSelected ? themeColor : (selectedDistrictCount > 0 ? Color.orange : .white.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Nested Districts Accordion List
            if hasDistricts && isExpanded {
                VStack(spacing: 4) {
                    Divider()
                        .background(Color.white.opacity(0.08))
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)

                    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let displayedDistricts = query.isEmpty ? districts : districts.filter { $0.lowercased().contains(query) }

                    ForEach(displayedDistricts, id: \.self) { district in
                        let isDistrictOn: Bool = {
                            if localAllTracked { return true }
                            guard let entry = localSelectionMap[regionName] else { return false }
                            if let set = entry {
                                return set.contains(district)
                            }
                            return true // nil = вся область
                        }()

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                toggleDistrict(regionName: regionName, district: district, allDistricts: districts)
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(isDistrictOn ? themeColor : .white.opacity(0.3))

                                Text(district)
                                    .font(.system(size: 13, weight: isDistrictOn ? .medium : .regular))
                                    .foregroundColor(isDistrictOn ? .white : .white.opacity(0.65))

                                Spacer()

                                Image(systemName: isDistrictOn ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(isDistrictOn ? themeColor : .white.opacity(0.2))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(isDistrictOn ? themeColor.opacity(0.06) : Color.white.opacity(0.02))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isRegionActive ? themeColor.opacity(0.07) : Color.white.opacity(0.03))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isRegionActive ? themeColor.opacity(0.28) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Selection Actions
    private func toggleWholeRegion(regionName: String, allDistricts: [String]) {
        if localAllTracked {
            localAllTracked = false
            localSelectionMap.removeAll()
            for r in allRegionsList {
                if r != regionName {
                    localSelectionMap[r] = nil
                }
            }
        } else {
            let isCurrentlyActive = localSelectionMap.keys.contains(regionName)
            let isCurrentlyWhole = localSelectionMap[regionName] == nil
            if isCurrentlyActive && isCurrentlyWhole {
                // Вимикаємо область повністю
                localSelectionMap.removeValue(forKey: regionName)
            } else {
                // Вмикаємо всю область
                localSelectionMap[regionName] = nil
            }
        }
        checkIfAllTracked()
    }

    private func toggleDistrict(regionName: String, district: String, allDistricts: [String]) {
        if localAllTracked {
            localAllTracked = false
            localSelectionMap.removeAll()
            for r in allRegionsList {
                if r == regionName {
                    var set = Set(allDistricts)
                    set.remove(district)
                    localSelectionMap[r] = set
                } else {
                    localSelectionMap[r] = nil
                }
            }
        } else {
            if let existing = localSelectionMap[regionName] {
                if var set = existing {
                    if set.contains(district) {
                        set.remove(district)
                    } else {
                        set.insert(district)
                    }
                    if set.isEmpty {
                        localSelectionMap.removeValue(forKey: regionName)
                    } else if set.count == allDistricts.count {
                        localSelectionMap[regionName] = nil
                    } else {
                        localSelectionMap[regionName] = set
                    }
                } else {
                    // Раніше була вся область, тепер знімаємо один район
                    var set = Set(allDistricts)
                    set.remove(district)
                    localSelectionMap[regionName] = set
                }
            } else {
                // Область була вимкнена, вмикаємо лише цей один район
                localSelectionMap[regionName] = Set([district])
            }
        }
        checkIfAllTracked()
    }

    private func checkIfAllTracked() {
        if localSelectionMap.count == allRegionsList.count && localSelectionMap.values.allSatisfy({ $0 == nil }) {
            localAllTracked = true
        } else {
            localAllTracked = false
        }
    }

    private var selectionSummaryTitle: String {
        if localAllTracked {
            return "Усі області"
        }
        let totalCount = localSelectionMap.count
        return "\(totalCount) обл."
    }

    // MARK: - Persistence
    private func loadInitialState() {
        localAllTracked = allRegionsTracked
        localSelectionMap.removeAll()

        if localAllTracked {
            for r in allRegionsList {
                localSelectionMap[r] = nil
            }
        } else {
            let entries = trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }
            for entry in entries {
                if let colonIdx = entry.firstIndex(of: ":") {
                    let rName = String(entry[..<colonIdx])
                    let dStr = String(entry[entry.index(after: colonIdx)...])
                    let dSet = Set(dStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) })
                    localSelectionMap[rName] = dSet
                } else {
                    localSelectionMap[entry] = nil
                }
            }
        }
    }

    private func saveAndConfirm() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if localAllTracked || (localSelectionMap.count == allRegionsList.count && localSelectionMap.values.allSatisfy({ $0 == nil })) {
            allRegionsTracked = true
            trackedRegionsString = allRegionsList.joined(separator: ";")
        } else {
            allRegionsTracked = false
            var entries: [String] = []
            for (r, distSetOpt) in localSelectionMap {
                if let distSet = distSetOpt {
                    if !distSet.isEmpty {
                        entries.append("\(r):\(distSet.joined(separator: ","))")
                    }
                } else {
                    entries.append(r)
                }
            }
            trackedRegionsString = entries.joined(separator: ";")
        }
        onConfirm()
        dismiss()
    }
}

