# Project Rules & Architecture for SirenUA

## 🚨 Critical Repository Mapping & Sync Rules (SirenUA & SirenUA-ThreatServer)

This workspace consists of two separate repositories. The AI agent **MUST** proactively manage and ensure proper synchronization of both repositories:

1. **iOS Application Repository (Master Codebase)**:
   - Repository: `https://github.com/atlastrinity/SirenUA`
   - Local directory: `/Users/dev/Documents/GitHub/claw-code/serena/SirenUA`
   - Contains: Swift codebase for iOS client, and the master copy of the threat server code under the `/threat_server` directory (which serves as the master database with full git history).
   - **Rule**: EVERY change (iOS and server-side) **MUST** be committed and pushed to this master repository first or simultaneously.

2. **Render Threat Server Repository (Deployment Only)**:
   - Repository: `https://github.com/atlastrinity/SirenUA-ThreatServer`
   - Cloned directory: `/Users/dev/Documents/GitHub/claw-code/serena/SirenUA-ThreatServer`
   - Contains: ONLY Python FastAPI backend code and server deployment configuration files.
   - **Crucial Rule**: The live deployment on Render is connected ONLY to this repository. Pushing here triggers automatic deployment.

### Server Deployment Process

Whenever changes are made to the threat server code (e.g. `mock_mode.py`, `telegram_monitor.py`, `server.py`, `shelter_manager.py`):

1. **Sync Instantly**: The agent **MUST** copy the changes between `/SirenUA/threat_server` and `/SirenUA-ThreatServer` to keep them 100% identical.
2. **Double Commit & Push**: The agent **MUST** commit and push the changes to **BOTH** repositories.
3. **Verify Git Status**: The agent **MUST** run `git status` in both directories at the end of the task to verify no uncommitted server files are left behind.
4. Only pushing to `SirenUA-ThreatServer.git` (branch `main`) triggers Render's automated build and redeployment. Pushing changes to the `/threat_server` subfolder in the `SirenUA` repository will **NOT** update the live server.

## 🤖 AI Automation & CI/CD Capabilities

The AI agent has full access to automate the entire development and deployment lifecycle for this project. The agent MUST proactively use the following tools instead of asking the user to perform manual UI actions:

1. **Builds & Deployments (Fastlane)**
   - **Rule:** NEVER use Xcode Cloud for builds. ALWAYS use **Fastlane** via the terminal (`run_command` tool).
   - **Command:** Use `fastlane beta` to automatically increment the build number, compile the `.ipa`, and upload it to TestFlight.
   - The App Store Connect API keys are pre-configured in `.env` and `fastlane/Fastfile`.

2. **Local iOS Development (MCP Servers)**
   - `xcode-bridge`: Use this to build the project locally, run tests, format code, and manage Xcode project files programmatically.
   - `swiftlens`: Use this for deep semantic search, finding references, and understanding Swift architecture via SourceKit-LSP.
   - `ios-simulator`: Use this to launch the app in the iOS Simulator, tap on UI elements, and take screenshots for validation.

3. **App Store Management (MCP Server)**
   - `appstore-connect`: Use this to manage app metadata, read/triage user reviews, and generate Release Notes automatically via the App Store Connect API.

When the user requests a full cycle (e.g., "build and release a new version"), the agent should autonomously orchestrate these tools (e.g., compile locally -> run tests -> fastlane beta -> update release notes via MCP).

## 🎯 Основна ціль системи

**SirenUA — це система раннього попередження про повітряні загрози для цивільного населення України.**

Усі розробки, промпти ШІ, логіка обробки повідомлень та оптимізації ПЗ мають бути підпорядковані виключно цій цілі: максимально швидке, точне та енергоефективне інформування про реальні загрози, без перевантаження каналів зв'язку та API.

### Операційні правила системи & Набутий досвід

1. **Мова інтерфейсу та сповіщень**: Системні інструкції ШІ пишуться англійською для точності логіки, але вивід для користувача (пуш, описание, деталі) має бути виключно українською мовою.
2. **Фільтрація нецільових повідомлень**: Інформаційні та аналітичні повідомлення без прямої поточної загрози (наприклад, звіти про збиття за минулу ніч, заяви політиків тощо) повинні мати рівень загрози `none` та відсікатися на ранньому етапі для економії ресурсів API Gemini та Firestore.
3. **Енергоефективність клієнта**: Забороняється використання постійних з'єднань на кшталт WebSocket. Додаток повинен працювати в режимі реактивного оновлення: FCM Push-сповіщення тригерить одноразовий HTTP-запит `GET /api/threats` для перемальовування інтерфейсу, з резервним HTTP-опитуванням кожні 30 секунд.
4. **Захист від звукового спаму (FCM Debouncing)**: При масових повітряних атаках (одночасна зміна статусу загроз у 10+ регіонах), сповіщення мають надсилатися батчем, при цьому звуковий сигнал дозволено програвати лише на першому сповіщенні з батчу.
5. **Оптимізація рендерингу карти та усунення мерцання (Map Zoom Performance)**:
   - **Заборонено** використовувати `.onMapCameraChange(frequency: .continuous)` для передачі параметрів у `@Published` змінні SwiftUI View. Це викликає 120-герцове перемальовування й мерцання анотацій та поліліній.
   - Використовувати `.onMapCameraChange(frequency: .onEnd)` та поріг відносної зміни відстані камери (відносний поріг >= 15%) у `MapViewModel.updateCameraDistance`.
6. **Регіональна груповість правил Gemini (Region-Grouped Rules Engine)**:
   - Правила навчальної бази `gemini_rules` обов'язково групуються за областями (`source_region`, `target_region`, `region_group`).
   - Під час аналізу події для області Gemini завантажує ВСІ актуальні правила для даного регіонального кластеру з порогом `evidence_count >= 1` та `accuracy_score >= 0.40`.
7. **Інтелектуальне зшивання розривів траєкторій (Trajectory Gap Stitching)**:
   - При виникненні розривів у радіолокаційній детекції проміжні області автоматично активуються як проміжний коридор перельоту (`is_predictive = True`, `is_detection_gap = True`) на основі BFS на графі `UKRAINE_TOPOLOGY`.
   - На iOS карті неперервність комети зберігається, а ділянки розриву візуалізуються пунктирним неоновим лазером.
8. **Єдині константи загроз (Single Source of Truth)**:
   - Усі сервісні файли сервера повинні використовувати виключно константи `THREAT_*` з `core/threat_types.py` (`THREAT_SHAHED`, `THREAT_BALLISTIC`, `THREAT_MIG31K` тощо).
9. **Строга фільтрація укриттів (Real Bomb Shelters)**:
   - Логіка пошуку укриттів повинна шукати тільки підземні паркінги, бомбосховища та реальні об'єкти цивільного захисту, строго відсікаючи зупинки транспорту та укриття від дощу.
