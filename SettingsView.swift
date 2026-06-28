import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("autoRefreshEnabled") private var autoRefreshEnabled = true
    @AppStorage("refreshInterval") private var refreshInterval = 30
    @AppStorage("mapType") private var mapType = 0
    @AppStorage("walkingSearchRadius") private var walkingSearchRadius = 1.5
    @AppStorage("drivingSearchRadius") private var drivingSearchRadius = 5.0
    @AppStorage("premiumEnabled") private var premiumEnabled = true
    @AppStorage("threatServerURL") private var threatServerURL = "https://eb3e-185-94-219-55.ngrok-free.app"
    @AppStorage("allRegionsTracked") private var allRegionsTracked = true
    @AppStorage("trackedRegionsString") private var trackedRegionsString = ""

    // Список усіх 25 областей
    private let allRegionsList = [
        "Вінницька область", "Волинська область", "Дніпропетровська область",
        "Донецька область", "Житомирська область", "Закарпатська область",
        "Запорізька область", "Івано-Франківська область", "Київська область",
        "м. Київ", "Кіровоградська область", "Луганська область",
        "Львівська область", "Миколаївська область", "Одеська область",
        "Полтавська область", "Рівненська область", "Сумська область",
        "Тернопільська область", "Харківська область", "Херсонська область",
        "Хмельницька область", "Черкаська область", "Чернівецька область",
        "Чернігівська область"
    ]

    private func isTracked(_ name: String) -> Bool {
        if trackedRegionsString.isEmpty && allRegionsTracked {
            return true
        }
        let list = trackedRegionsString.components(separatedBy: ";")
        return list.contains(name)
    }

    private func setTracked(_ name: String, isOn: Bool) {
        var list = trackedRegionsString.components(separatedBy: ";").filter { !$0.isEmpty }
        if isOn {
            if !list.contains(name) {
                list.append(name)
            }
        } else {
            list.removeAll { $0 == name }
        }
        trackedRegionsString = list.joined(separator: ";")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Кастомний навігаційний бар
            HStack {
                Spacer()
                Text("Налаштування")
                    .font(.headline)
                    .padding(.leading, 40)
                Spacer()
                Button("Готово") {
                    dismiss()
                }
                .fontWeight(.bold)
            }
            .padding()
            .background(Color.clear)

            Form {
                Section(header: Text("Сповіщення")) {
                    Toggle("Увімкнути сповіщення", isOn: $notificationsEnabled)
                    Toggle("Автооновлення", isOn: $autoRefreshEnabled)

                    if autoRefreshEnabled {
                        Stepper("Інтервал: \(refreshInterval) сек", value: $refreshInterval, in: 15...300, step: 15)
                    }
                }
                .listRowBackground(Color.clear)

                Section(header: Text("Карта та Навігація")) {
                    Picker("Тип карти", selection: $mapType) {
                        Text("Стандартна").tag(0)
                        Text("Гібридна").tag(1)
                        Text("Супутник").tag(2)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading) {
                            Text("Радіус пошуку пішки: \(walkingSearchRadius, specifier: "%.1f") км")
                            Slider(value: $walkingSearchRadius, in: 0.5...3.0, step: 0.5)
                        }
                        VStack(alignment: .leading) {
                            Text("Радіус пошуку авто: \(drivingSearchRadius, specifier: "%.1f") км")
                            Slider(value: $drivingSearchRadius, in: 1.0...20.0, step: 1.0)
                        }
                    }
                }
                .listRowBackground(Color.clear)

                Section(header: Text("Premium Моніторинг")) {
                    Toggle("SirenUA Premium (Загрози)", isOn: $premiumEnabled)
                    if premiumEnabled {
                        HStack {
                            Text("Сервер:")
                                .foregroundColor(.gray)
                            TextField("http://localhost:8080", text: $threatServerURL)
                                .autocorrectionDisabled()
                        }
                    }
                }
                .listRowBackground(Color.clear)

                Section(header: Text("Області для попереджень")) {
                    Toggle("Усі області", isOn: Binding(
                        get: { allRegionsTracked },
                        set: { trackingAll in
                            allRegionsTracked = trackingAll
                            if trackingAll {
                                trackedRegionsString = allRegionsList.joined(separator: ";")
                            } else {
                                trackedRegionsString = ""
                            }
                        }
                    ))
                    
                    if !allRegionsTracked {
                        ForEach(allRegionsList, id: \.self) { region in
                            Toggle(region, isOn: Binding(
                                get: { isTracked(region) },
                                set: { isOn in
                                    setTracked(region, isOn: isOn)
                                }
                            ))
                        }
                    }
                }
                .listRowBackground(Color.clear)

                Section(header: Text("Вигляд")) {
                    Toggle("Темна тема", isOn: .constant(true))
                    Toggle("Великі іконки", isOn: .constant(false))
                }
                .listRowBackground(Color.clear)

                Section(header: Text("Про додаток")) {
                    Text("SirenUA")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("iOS додаток для відображення повітряних тривог в Україні")
                        .font(.caption)
                    Text("Версія 4.1")
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .environment(\.defaultMinListRowHeight, 50)
        }
        .background(Color.black.opacity(0.4))
        .preferredColorScheme(.dark)
    }
}
