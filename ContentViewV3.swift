import SwiftUI

@available(iOS 17.0, *)
struct ContentViewV3: View {
    @StateObject private var viewModel = AlertViewModelV3()
    @State private var selectedAlert: AlertRegion?
    @State private var showSettings = false
    @State private var showAbout = false

    var body: some View {
        ZStack {
            // Карта України
            MapViewV3(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)

            // Верхня панель з меню
            VStack(alignment: .trailing, spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation {
                            viewModel.refreshAlerts()
                        }
                    }) {
                        Image(systemName: viewModel.isLoading ? "gauge.with.dots.that.fill" : "arrow.clockwise.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .symbolEffect(.bounce, value: viewModel.isLoading)
                            .padding(12)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    .shadow(color: .black.opacity(0.15), radius: 15, y: 8)
                    .sensoryFeedback(.impact, trigger: viewModel.isLoading)
                    .disabled(viewModel.isLoading)

                    Button(action: {
                        withAnimation {
                            showSettings = true
                        }
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .symbolEffect(.bounce, value: showSettings)
                            .padding(12)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    .shadow(color: .black.opacity(0.15), radius: 15, y: 8)
                    .sensoryFeedback(.impact, trigger: showSettings)

                    Button(action: {
                        withAnimation {
                            showAbout = true
                        }
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .symbolEffect(.bounce, value: showAbout)
                            .padding(12)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    .shadow(color: .black.opacity(0.15), radius: 15, y: 8)
                    .sensoryFeedback(.impact, trigger: showAbout)
                }
                .padding()

                // Статусна панель
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(viewModel.activeAlerts > 0 ? Color.red : Color.green)
                            .frame(width: 12, height: 12)
                            .shadow(radius: 4)
                        Text("\(viewModel.activeAlerts) активних тривог")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }

                    if viewModel.maxLevel > 0 {
                        HStack(spacing: 8) {
                            Text("Макс. рівень:")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Text("\(viewModel.maxLevel)/4")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        .shadow(color: .black.opacity(0.15), radius: 15, y: 8)
                )
            }
            .padding()

            // Детальний вигляд при виборі тривоги
            if let alert = selectedAlert {
                AlertRegionDetailView(region: alert)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .onChange(of: selectedAlert) { oldValue, newValue in
            if newValue == nil {
                // Обробка закриття детального вигляду
            }
        }
    }
}

@available(iOS 17.0, *)
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var notificationsEnabled = true
    @State private var autoRefreshEnabled = true
    @State private var refreshInterval = 5

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Сповіщення")) {
                    Toggle("Увімкнути сповіщення", isOn: $notificationsEnabled)
                    Toggle("Автооновлення", isOn: $autoRefreshEnabled)

                    if autoRefreshEnabled {
                        Stepper("Інтервал: \(refreshInterval) хв", value: $refreshInterval, in: 1...60)
                    }
                }

                Section(header: Text("Вигляд")) {
                    Toggle("Темна тема", isOn: .constant(true))
                    Toggle("Великі іконки", isOn: .constant(false))
                }

                Section(header: Text("Про додаток")) {
                    Text("SirenUA")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("iOS додаток для відображення повітряних тривог в Україні")
                        .font(.caption)
                    Text("Версія 2.0")
                }
            }
            .navigationTitle("Налаштування")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                        .padding()

                    Text("SirenUA")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("iOS додаток для відображення повітряних тривог в Україні")
                        .font(.body)

                    Divider()

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🛡️ Мета")
                                .fontWeight(.bold)
                            Text("Надавати оперативну інформацію про повітряні тривоги")
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("🌍 Функціональність")
                                .fontWeight(.bold)
                            Text("• Інтерактивна карта України")
                            Text("• Реальний час")
                            Text("• Налаштування сповіщень")
                            Text("• Детальна інформація")
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("📱 Технології")
                                .fontWeight(.bold)
                            Text("• SwiftUI")
                            Text("• MapKit")
                            Text("• iOS 17+")
                        }
                    }
                    .padding()

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ліцензія")
                            .fontWeight(.bold)
                        Text("Open Source")
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle("Про додаток")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрити") {
                        dismiss()
                    }
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct ContentViewV3_Previews: PreviewProvider {
    static var previews: some View {
        ContentViewV3()
    }
}
