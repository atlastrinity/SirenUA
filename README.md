# SirenUA - iOS додаток для відображення повітряних тривог

Це iOS додаток на SwiftUI, який відображає активні повітряні тривоги в Україні на інтерактивній карті.

## 📱 Функціональність

- 🗺️ Інтерактивна карта України з точками тривог
- 🚨 Відображення активних тривог (червоні індикатори)
- ✅ Відображення неактивних тривог (зелені індикатори)
- 📋 Картка статусу з кількістю активних тривог
- 📄 Детальна інформація про кожну тривогу

## 🏗️ Архітектура

### Мережевий шар (NetworkManager)
- Async/Await для асинхронних запитів
- Мок-дані для симуляції API (alerts.in.ua)
- ObservableObject для управління станом

### SwiftUI компоненти
- **MapView**: Карта з анотаціями тривог
- **AlertStatusCard**: Картка статусу внизу екрана
- **AlertDetailView**: Детальний вигляд тривоги
- **SirenUAApp**: Main entry point

## 🚀 Запуск проєкту

### Вимоги
- iOS 17.0+
- Xcode 15.0+

### Інструкції

1. **Відкрийте проєкт у Xcode:**
   ```bash
   open SirenUA/SirenUA.xcodeproj
   ```

2. **Виберіть ціль:** `SirenUA`
3. **Виберіть симулятор:** iPhone 16 Pro Max або будь-який інший iOS 17+ симулятор
4. **Натисніть Run (⌘R)**

### Команда для командного рядка

```bash
cd SirenUA
swift build
```

## 📁 Структура проєкту

```
SirenUA/
├── Sources/SirenUA/
│   ├── SirenUAApp.swift       # Main app entry point
│   ├── SceneDelegate.swift    # Scene delegate for UIKit integration
│   ├── NetworkManager.swift   # Network layer with mock data
│   ├── ContentView.swift      # Main view with map
│   ├── MapView.swift          # Interactive map
│   ├── AlertStatusCard.swift  # Status card
│   └── AlertDetailView.swift  # Alert details
├── Tests/SirenUATests/
│   └── SirenUATests.swift     # Unit tests
├── Package.swift              # Swift Package Manager config
├── Info.plist                 # App configuration
└── create_xcode_project.sh    # Script to create Xcode project
```

## 🎨 Дизайн

- **Активні тривоги**: Червоні індикатори на карті
- **Неактивні тривоги**: Зелені індикатори
- **UI**: Сучасний SwiftUI дизайн з закругленими кутами та тінями
- **Кольори**: Дотримуються гайдлайнів Apple Human Interface Guidelines

## 📝 Додаткова інформація

### Мок-дані
Зараз додаток використовує статичні мок-дані для демонстрації:
```json
[
  {
    "id": "1",
    "region": "Kyiv",
    "active": true,
    "type": "air_raid",
    "changed": "2026-06-26T12:00:00Z"
  }
]
```

### Майбутнє розширення
- Реалізація справжнього API alerts.in.ua
- Підтримка оновлення в реальному часі через WebSocket
- Геолокація для визначення близьких тривог
- Налаштування сповіщень

## 📄 Ліцензія

MIT

## 🤝 Внесок

Звітите про проблеми та пропонуйте покращення через GitHub Issues.
