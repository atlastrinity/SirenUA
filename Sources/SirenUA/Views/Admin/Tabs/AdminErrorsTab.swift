import SwiftUI
import Charts

struct AdminErrorsTab: View {
    @ObservedObject var viewModel: AdminViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Filters Section
            VStack(spacing: 8) {
                HStack {
                    Text("Фільтри")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    Picker("Система (Джерело)", selection: $viewModel.errSourceFilter) {
                        Text("Всі").tag("")
                        Text("Server").tag("server")
                        Text("Firebase").tag("firebase")
                        Text("Gemini").tag("gemini")
                        Text("Telegram").tag("telegram")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    
                    Picker("Тип Помилки", selection: $viewModel.errTypeFilter) {
                        Text("Всі").tag("")
                        Text("429 Ліміт").tag("429_rate_limit")
                        Text("404 Не знайдено").tag("404_not_found")
                        Text("500 Сервер").tag("500_server")
                        Text("Таймаут").tag("timeout")
                        Text("Мережа").tag("network_error")
                        Text("Авторизація").tag("auth")
                        Text("Системні").tag("systemic")
                        Text("Firebase").tag("firebase_error")
                        Text("Telegram").tag("telegram_error")
                        Text("Gemini").tag("gemini_api_error")
                        Text("JSON").tag("json_parse_error")
                        Text("База даних").tag("database_error")
                        Text("Валідація").tag("validation_error")
                        Text("Інші").tag("general")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    
                    Picker("Днів", selection: $viewModel.errDaysFilter) {
                        Text("1 д").tag(1)
                        Text("3 д").tag(3)
                        Text("7 д").tag(7)
                        Text("30 д").tag(30)
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    
                    Button(action: {
                        Task { await viewModel.fetchErrors() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(10)
            .background(ChartColorTheme.cardBg)
            .cornerRadius(12)
            
            
            VStack(spacing: 16) {
                    // Stats cards grid
                    if let stats = viewModel.errorStats {
                        VStack(alignment: .leading, spacing: 12) {
                            statBox(title: "Всього помилок", value: "\(stats.total)", color: .red)
                            
                            let activeTypes = stats.by_type.filter { $0.count > 0 }
                            if !activeTypes.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Розподіл за категоріями:")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                        .padding(.top, 2)
                                    
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                        ForEach(activeTypes) { item in
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(viewModel.formatErrorType(item.error_type))
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(.white.opacity(0.7))
                                                    .lineLimit(1)
                                                Text("\(item.count)")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(
                                                        item.error_type.contains("rate_limit") ? .yellow :
                                                        item.error_type.contains("api") || item.error_type.contains("firebase") || item.error_type.contains("telegram") ? .orange :
                                                        item.error_type.contains("database") || item.error_type.contains("json") ? .purple :
                                                        item.error_type.contains("network") ? .cyan : .red
                                                    )
                                            }
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.white.opacity(0.02))
                                            .cornerRadius(6)
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.04), lineWidth: 1))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Swift Charts Section
                    if let stats = viewModel.errorStats {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Джерела помилок")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Chart {
                                ForEach(stats.by_source) { item in
                                    BarMark(
                                        x: .value("Count", item.count),
                                        y: .value("Source", item.source)
                                    )
                                    .foregroundStyle(
                                        item.source == "server" ? Color.blue :
                                        item.source == "firebase" ? Color.orange : Color.purple
                                    )
                                }
                            }
                            .frame(height: 120)
                        }
                        .padding(14)
                        .background(ChartColorTheme.cardBg)
                        .cornerRadius(12)
                        
                        // Hourly error chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Розподіл помилок за годинами (48г)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Chart {
                                ForEach(stats.hourly) { item in
                                    BarMark(
                                        x: .value("Hour", item.hour),
                                        y: .value("Count", item.count)
                                    )
                                    .foregroundStyle(Color.red)
                                }
                            }
                            .frame(height: 120)
                        }
                        .padding(14)
                        .background(ChartColorTheme.cardBg)
                        .cornerRadius(12)
                    }
                    
                    // Errors List Table
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Записи помилок (\(viewModel.errorsList.count))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        if viewModel.errorsList.isEmpty {
                            Text("Не знайдено помилок за вибраний період 🎉")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .padding(.vertical, 20)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(viewModel.errorsList.prefix(50)) { error in
                                    let isExpanded = (viewModel.expandedErrorId == error.id)
                                    ErrorEventRow(error: error, viewModel: viewModel, isExpanded: isExpanded)
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                viewModel.expandedErrorId = isExpanded ? nil : error.id
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(ChartColorTheme.cardBg)
                    .cornerRadius(12)
            }
            .onChange(of: viewModel.errSourceFilter) { _, _ in
                Task { await viewModel.fetchErrors() }
            }
            .onChange(of: viewModel.errTypeFilter) { _, _ in
                Task { await viewModel.fetchErrors() }
            }
            .onChange(of: viewModel.errDaysFilter) { _, _ in
                Task { await viewModel.fetchErrors() }
            }
        }
    }
    
    private func statBox(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

struct ErrorEventRow: View {
    let error: AdminErrorEntry
    let viewModel: AdminViewModel
    let isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(error.source.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        error.source == "server" ? Color.blue.opacity(0.2) :
                        error.source == "firebase" ? Color.orange.opacity(0.2) : Color.purple.opacity(0.2)
                    )
                    .foregroundColor(
                        error.source == "server" ? Color.blue :
                        error.source == "firebase" ? Color.orange : Color.purple
                    )
                    .cornerRadius(4)
                
                Text(viewModel.formatErrorType(error.error_type))
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(4)
                
                Spacer()
                
                Text(viewModel.formatShortTime(error.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Text(error.message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(isExpanded ? nil : 2)
            
            if isExpanded {
                if let endpoint = error.endpoint, !endpoint.isEmpty {
                    HStack(alignment: .top) {
                        Text("Маршрут:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text(endpoint)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                    .padding(.top, 2)
                }
                
                if let context = error.context, !context.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Контекст:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                        Text(context)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(6)
                            .background(Color.black.opacity(0.25))
                            .cornerRadius(4)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(isExpanded ? 0.05 : 0.02))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isExpanded ? Color.red.opacity(0.2) : Color.clear, lineWidth: 1))
    }
}

