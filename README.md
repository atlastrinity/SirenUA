# SirenUA - iOS додаток раннього попередження про повітряні загрози

SirenUA — це сучасний iOS додаток на SwiftUI для моніторингу повітряних тривог, прогнозування векторів загроз (ракети, дрони, балістика) за допомогою ШІ та миттєвого пошуку найближчих захисних споруд і бомбосховищ.

## 📱 Ключова функціональність

- 🗺️ **Інтерактивна карта України**: Візуалізація загроз у реальному часі (червоні зони тривог, жовті зони підвищеної небезпеки, комети траєкторій польоту БПЛА/ракет).
- 🛡️ **Система пошуку укриттів та навігації**:
  - **Миттєве центрування карти**: При пошуку укриття карта плавно фокусується на користувачеві.
  - **3-рівневий каскадний пошук**:
    1. *Базовий радіус користувача* (0.5–5 км для пішоходів, 1–20 км для авто).
    2. *Локальний розширений периметр* (до 6 км пішки / 15 км авто для сусідніх сіл та меж міста).
    3. *Районний периметр цивільного захисту* (до 15–30 км для пошуку найближчої захисної споруди району або райцентру).
  - **Джерела даних**: Вбудований офіційний реєстр захисних споруд (школи, ліцеї, садочки, адмінбудівлі, ПРУ), ThreatServer API з live Overpass targeted query та Apple MapKit.
  - **Маршрутизація**: Автоматична побудова безпечного маршруту через `MKDirections` з відображенням відстані та часу пересування.
  - **Фільтрація та дедуплікація**: Використання виключно об'єктів цивільного захисту (бомбосховища, станції метро, підземні паркінги, ПРУ, навчальні та муніципальні укриття).
- 🤖 **ШІ-Радар та Аналітика**: Оцінка вірогідності загроз, динамічний ETA підльоту та автоматична агрегація даних.
- 🔔 **Гнучкі сповіщення**: 6 незалежних тогглів (критичні сповіщення, тривога, ШІ-загрози, відбій, вібрація) з підтримкою Notification Service Extension.
- 🧭 **4-панельна навігація**: Таббар Glassmorphism (Карта, Хронологія, Укриття, Профіль).

## 🏗️ Архітектура додатку

### Модулі та сервіси (`Sources/SirenUA/`)

```text
Sources/SirenUA/
├── Models/
│   ├── AlertRegion.swift               # Модель областей, статусів тривог та загроз
│   ├── ShelterItem.swift               # ShelterItem, ShelterType enum, ShelterFormatter
│   ├── EventType.swift                 # Типи подій (alarm, threat, clear) та звукова політика
│   └── ThreatConstants.swift           # Константи типів загроз (Shahed, Ballistic тощо)
├── Services/
│   ├── ShelterSearchService.swift      # Пошук укриттів (OSM API + MKLocalSearch fallback)
│   └── ShelterRouteService.swift       # Розрахунок маршрутів та адаптивної камери карти
├── ViewModels/
│   ├── AlertViewModelV3.swift          # Управління станом тривог та ШІ-загроз
│   ├── MapViewModel.swift              # Управління станом карти, фокусом та таббаром
│   └── MapViewModel+ShelterSearch.swift# Розширення пошуку укриттів і центрування
├── Managers/
│   ├── NetworkManager.swift            # Мережевий шар API (Threats, Alerts, Shelters)
│   ├── LocationManager.swift           # Робота з CoreLocation та GPS-фіксацією
│   ├── NotificationManager.swift       # Делегат FCM пуш-сповіщень та підписок
│   └── GeoJSONManager.swift            # Завантаження та парсинг геополігонів областей
├── Views/
│   ├── Main/
│   │   ├── ContentView.swift           # Головний екран картографічного інтерфейсу
│   │   ├── ContentView+MapLayers.swift # Полігони областей, стилі карти, трекінг
│   │   └── ContentView+Sheets.swift    # Маршрутизація модальних вікон
│   ├── Components/
│   │   ├── MainTabBarView.swift        # 4-кнопковий Capsule Tab Bar з Glassmorphism
│   │   ├── BottomDashboardV4.swift     # Інтерактивна панель пошуку укриттів
│   │   ├── ShelterDetailView.swift     # Детальна картка знайденого укриття та CTA
│   │   ├── NavigationOverlay.swift     # HUD покрокової GPS-навігації
│   │   └── ThreatMapContent.swift      # MapContent шари, анотації та комети
│   └── Settings/
│       └── Cards/MapSettingsCard.swift # Налаштування радіусу пішки / на авто
```

## 🚀 Збірка та запуск

### Вимоги
- iOS 17.0+
- Xcode 15.0+ / Xcode 16+
- XcodeGen (`brew install xcodegen`)

### Команди збірки

1. **Генерація проекту через XcodeGen:**
   ```bash
   cd SirenUA
   xcodegen generate
   ```

2. **Запуск збірки через xcodebuild:**
   ```bash
   xcodebuild -project SirenUA.xcodeproj -scheme SirenUA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build CODE_SIGNING_ALLOWED=NO
   ```

3. **Запуск юніт-тестів:**
   ```bash
   xcodebuild test -project SirenUA.xcodeproj -scheme SirenUA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
   ```

## 📄 Ліцензія

Proprietary / SirenUA Team
