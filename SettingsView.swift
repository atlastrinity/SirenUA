import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("autoRefreshEnabled") private var autoRefreshEnabled = true
    @AppStorage("refreshInterval") private var refreshInterval = 30
    @AppStorage("showRadar") private var showRadar = true
    @AppStorage("mapType") private var mapType = 0
    @AppStorage("searchRadius") private var searchRadius = 3.0

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
                    Toggle("Показувати радар тривоги", isOn: $showRadar)
                    
                    Picker("Тип карти", selection: $mapType) {
                        Text("Стандартна").tag(0)
                        Text("Гібридна").tag(1)
                        Text("Супутник").tag(2)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Радіус пошуку укриттів: \(searchRadius, specifier: "%.1f") км")
                        Slider(value: $searchRadius, in: 0.5...5.0, step: 0.5)
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
