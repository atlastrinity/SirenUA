import Foundation

// MARK: - AlertViewModelV3 Threat Fetching & Applying

/// Регіони, які завжди червоні (тимчасово окуповані території) — сервер не може їх деактивувати
private let permanentlyActiveRegions: Set<String> = ["Автономна Республіка Крим"]

extension AlertViewModelV3 {

    /// Fetches full threat state from server via GET /api/threats.
    /// Called on: init, every 30s (polling), and on FCM push trigger.
    func fetchThreatState() async {
        guard !isFetching else { return }
        isFetching = true

        do {
            async let threatsTask = networkManager.fetchThreats(serverURL: threatServerURL)
            async let liveAlertsTask = networkManager.fetchLiveAlerts()

            let threats = try await threatsTask
            let liveAlerts = try? await liveAlertsTask

            applyThreats(threats)
            if let liveAlerts, !liveAlerts.isEmpty {
                applyLiveAlerts(liveAlerts)
            }

            updateStats()
            updateLastAlertedRegion()
            isFirstThreatFetch = false
            isFetching = false
        } catch {
            vmLogger.error("Error fetching threats: \(error.localizedDescription)")
            isFetching = false
            await fetchLiveAlerts()
        }
    }

    func applyThreats(_ threatData: [String: ThreatInfo]) {
        objectWillChange.send()
        for index in alerts.indices {
            let regionName = alerts[index].name
            // Крим завжди червоний — не оновлюємо з сервера
            if permanentlyActiveRegions.contains(regionName) { continue }
            guard let threat = threatData[regionName] else { continue }

            let oldThreatLevel = alerts[index].threatLevel
            let newThreatLevel = threat.level == "none" ? nil : threat.level
            let wasActive = alerts[index].isActive

            alerts[index].threatLevel = newThreatLevel
            alerts[index].threatType = threat.type
            alerts[index].threatDetail = threat.detail
            alerts[index].threatConfidence = threat.confidence
            alerts[index].threatETA = threat.eta
            alerts[index].isThreatPredictive = threat.is_predictive ?? false

            if let activeThreats = threat.active_threats, !activeThreats.isEmpty {
                alerts[index].activeThreats = activeThreats
                alerts[index].selectedThreatIndex = activeThreats.count - 1
            } else {
                alerts[index].activeThreats = []
                alerts[index].selectedThreatIndex = 0
            }

            if let isActive = threat.is_active {
                alerts[index].isActive = isActive
                alerts[index].level = isActive ? 3 : 0
                if isActive {
                    alerts[index].description = "Повітряна тривога!"
                } else if newThreatLevel != nil {
                    alerts[index].description = "Загроза"
                } else {
                    alerts[index].description = "Немає тривоги"
                }

                // Fire official siren sound (siren.wav) on transition to active state
                if !isFirstThreatFetch && !isFirstFetch {
                    if !wasActive && isActive {
                        NotificationManager.shared.sendAlertNotification(for: regionName)
                    } else if wasActive && !isActive {
                        NotificationManager.shared.sendClearNotification(for: regionName)
                    }
                }
            }

            if oldThreatLevel == nil && newThreatLevel != nil && !alerts[index].isActive {
                if !isFirstThreatFetch {
                    let confidence = threat.confidence ?? 75
                    let isPredictive = threat.is_predictive ?? false
                    if isPredictive && confidence < 50 {
                        vmLogger.info("Skipping notification for predictive low-confidence threat in \(regionName) (\(confidence)%)")
                        continue
                    }
                    let typeDesc = getThreatTypeDescription(threat.type ?? "")
                    let title = buildThreatTitle(type: threat.type, confidence: confidence, region: regionName)
                    var body = threat.detail ?? "Виявлено загрозу \(typeDesc)."
                    if let eta = threat.eta, !eta.isEmpty { body += " (Час: \(eta))" }
                    NotificationManager.shared.sendThreatNotification(
                        for: regionName, title: title, body: body,
                        confidence: confidence, isCritical: confidence >= 85
                    )
                }
            }
        }

        let hasActiveFlyingThreats = alerts.contains(where: { shouldShowFlyingThreat(for: $0) })
        if !hasActiveFlyingThreats {
            injectDemoThreats()
        }

        isFirstThreatFetch = false
    }

    func injectDemoThreats() {
        // Дніпропетровська область - БПЛА Shahed
        if let idx = alerts.firstIndex(where: { $0.name == "Дніпропетровська область" }) {
            alerts[idx].isActive = true
            alerts[idx].level = 3
            alerts[idx].threatLevel = "high"
            alerts[idx].threatType = "shahed"
            alerts[idx].threatDetail = "Виявлено БПЛА Shahed у напрямку Дніпра"
            alerts[idx].threatConfidence = 92
            alerts[idx].threatETA = "12 хв"
            alerts[idx].description = "Повітряна тривога!"
            alerts[idx].activeThreats = [
                SingleThreatInfo(
                    threat_id: "demo-shahed-1",
                    level: "high",
                    type: "shahed",
                    detail: "БПЛА Shahed-136 у напрямку міста",
                    since: "14:40",
                    confidence: 92,
                    eta: "12 хв",
                    is_predictive: false,
                    is_test: true,
                    group_id: "grp-demo-1",
                    origin_latitude: 47.2,
                    origin_longitude: 36.8,
                    last_checkpoint_latitude: 48.1,
                    last_checkpoint_longitude: 35.5
                )
            ]
            alerts[idx].selectedThreatIndex = 0
        }

        // Київська область - Крилата ракета
        if let idx = alerts.firstIndex(where: { $0.name == "Київська область" }) {
            alerts[idx].isActive = true
            alerts[idx].level = 3
            alerts[idx].threatLevel = "high"
            alerts[idx].threatType = "cruise_missile"
            alerts[idx].threatDetail = "Крилата ракета у напрямку Києва"
            alerts[idx].threatConfidence = 95
            alerts[idx].threatETA = "5 хв"
            alerts[idx].description = "Повітряна тривога!"
            alerts[idx].activeThreats = [
                SingleThreatInfo(
                    threat_id: "demo-missile-1",
                    level: "high",
                    type: "cruise_missile",
                    detail: "Крилата ракета Х-101",
                    since: "14:42",
                    confidence: 95,
                    eta: "5 хв",
                    is_predictive: false,
                    is_test: true,
                    group_id: "grp-demo-2",
                    origin_latitude: 51.5,
                    origin_longitude: 33.2,
                    last_checkpoint_latitude: 50.8,
                    last_checkpoint_longitude: 31.4
                )
            ]
            alerts[idx].selectedThreatIndex = 0
        }

        // Харківська область - КАБ
        if let idx = alerts.firstIndex(where: { $0.name == "Харківська область" }) {
            alerts[idx].isActive = true
            alerts[idx].level = 3
            alerts[idx].threatLevel = "high"
            alerts[idx].threatType = "kab"
            alerts[idx].threatDetail = "Пуск КАБ у напрямку Харкова"
            alerts[idx].threatConfidence = 88
            alerts[idx].threatETA = "3 хв"
            alerts[idx].description = "Повітряна тривога!"
            alerts[idx].activeThreats = [
                SingleThreatInfo(
                    threat_id: "demo-kab-1",
                    level: "high",
                    type: "kab",
                    detail: "Пуск КАБ з бєлгородської обл.",
                    since: "14:44",
                    confidence: 88,
                    eta: "3 хв",
                    is_predictive: false,
                    is_test: true,
                    group_id: "grp-demo-3",
                    origin_latitude: 50.5,
                    origin_longitude: 36.8,
                    last_checkpoint_latitude: 50.2,
                    last_checkpoint_longitude: 36.5
                )
            ]
            alerts[idx].selectedThreatIndex = 0
        }
    }

    func applySingleThreat(region: String, threat: ThreatInfo) {
        guard let index = alerts.firstIndex(where: { $0.name == region }) else { return }
        let oldThreatLevel = alerts[index].threatLevel
        let newThreatLevel = threat.level == "none" ? nil : threat.level
        let wasActive = alerts[index].isActive

        alerts[index].threatLevel = newThreatLevel
        alerts[index].threatType = threat.type
        alerts[index].threatDetail = threat.detail
        alerts[index].threatConfidence = threat.confidence
        alerts[index].threatETA = threat.eta
        alerts[index].isThreatPredictive = threat.is_predictive ?? false

        if let activeThreats = threat.active_threats, !activeThreats.isEmpty {
            alerts[index].activeThreats = activeThreats
            alerts[index].selectedThreatIndex = activeThreats.count - 1
        } else {
            alerts[index].activeThreats = []
            alerts[index].selectedThreatIndex = 0
        }

        if let isActive = threat.is_active {
            alerts[index].isActive = isActive
            alerts[index].level = isActive ? 3 : 0
            if isActive {
                alerts[index].description = "Повітряна тривога!"
            } else if newThreatLevel != nil {
                alerts[index].description = "Загроза"
            } else {
                alerts[index].description = "Немає тривоги"
            }

            if !isFirstThreatFetch && !isFirstFetch {
                if !wasActive && isActive {
                    NotificationManager.shared.sendAlertNotification(for: region)
                } else if wasActive && !isActive {
                    NotificationManager.shared.sendClearNotification(for: region)
                }
            }
        }

        if oldThreatLevel == nil && newThreatLevel != nil && !alerts[index].isActive {
            if !isFirstThreatFetch {
                let confidence = threat.confidence ?? 75
                let isPredictive = threat.is_predictive ?? false
                if isPredictive && confidence < 50 { return }
                let typeDesc = getThreatTypeDescription(threat.type ?? "")
                let title = buildThreatTitle(type: threat.type, confidence: confidence, region: region)
                var body = threat.detail ?? "Виявлено загрозу \(typeDesc)."
                if let eta = threat.eta, !eta.isEmpty { body += " (Час: \(eta))" }
                NotificationManager.shared.sendThreatNotification(
                    for: region, title: title, body: body,
                    confidence: confidence, isCritical: confidence >= 85
                )
            }
        }
    }

    // MARK: Live Alerts fallback

    func fetchLiveAlerts() async {
        guard !isFetching else { return }
        isFetching = true
        isLoading = true

        do {
            let liveData = try await networkManager.fetchLiveAlerts()
            applyLiveAlerts(liveData)
            isFirstFetch = false
            updateStats()
            firstNetworkFailureDate = nil
            errorMessage = nil
        } catch {
            vmLogger.error("Error fetching alerts: \(error.localizedDescription)")
            if firstNetworkFailureDate == nil {
                firstNetworkFailureDate = Date()
            }
            let duration = Date().timeIntervalSince(firstNetworkFailureDate!)
            if duration >= 120 {
                let mins = max(2, Int(duration / 60))
                errorMessage = "Відсутнє мережеве з'єднання (\(mins) хв). Перевірте інтернет."
            }
        }

        isLoading = false
        isFetching = false
    }

    func applyLiveAlerts(_ liveData: [String: AerialAlertState]) {
        objectWillChange.send()
        var newlyAlertedRegionName: String?

        for index in alerts.indices {
            let regionName = alerts[index].name
            // Крим завжди червоний — не оновлюємо з офіційних тривог
            if permanentlyActiveRegions.contains(regionName) { continue }
            guard let state = liveData[regionName] else { continue }

            let isAlertNow = state.alertnow
            let wasActive = alerts[index].isActive

            // OR-merge: Live API підтверджує тривогу, але НЕ скасовує якщо Threat API вже
            // поставив isActive=true (is_active: true). Це усуває race condition між двома
            // джерелами даних — якщо хоч одне каже "тривога" — область червона.
            let threatAlreadyActive = alerts[index].isActive && alerts[index].level == 3
            let effectiveActive = isAlertNow || threatAlreadyActive

            alerts[index].isActive = effectiveActive
            alerts[index].level = effectiveActive ? 3 : 0

            if effectiveActive {
                alerts[index].description = "Повітряна тривога!"
            } else if alerts[index].threatLevel != nil || !alerts[index].activeThreats.isEmpty {
                alerts[index].description = "Загроза"
            } else {
                alerts[index].description = "Немає тривоги"
            }

            alerts[index].lastChanged = state.changed

            guard !isFirstFetch else { continue }
            if !wasActive && effectiveActive {
                NotificationManager.shared.sendAlertNotification(for: regionName)
                newlyAlertedRegionName = regionName
            } else if wasActive && !effectiveActive {
                NotificationManager.shared.sendClearNotification(for: regionName)
            }
        }

        if let newRegionName = newlyAlertedRegionName {
            lastAlertedRegionName = newRegionName
            lastViewedTimestamp = nil
        } else if lastAlertedRegionName == nil || !(alerts.first(where: { $0.name == lastAlertedRegionName })?.isActive ?? false) {
            updateLastAlertedRegion()
        }
    }

    // MARK: Threat type helpers

    func getThreatTypeDescription(_ type: String) -> String {
        switch type {
        case "mig31k":         return "атаки аеробалістичними ракетами Кинджал"
        case "shahed":         return "ударних безпілотників Шахед"
        case "cruise_missile": return "крилатих ракет"
        case "kab":            return "ударів керованими авіабомбами (КАБ)"
        case "ballistic":      return "балістичних ракет"
        default:               return "повітряної атаки"
        }
    }

    func buildThreatTitle(type: String?, confidence: Int, region: String) -> String {
        let threatName: String
        switch type {
        case "ballistic":      threatName = "Балістична загроза"
        case "shahed":         threatName = "Загроза БпЛА Shahed"
        case "cruise_missile": threatName = "Загроза крилатих ракет"
        case "kab":            threatName = "Загроза КАБ"
        case "mig31k":         threatName = "Зліт МіГ-31К (Кинджал)"
        case "tu95":           threatName = "Зліт Ту-95МС (крилаті ракети)"
        case "tu22m3":         threatName = "Зліт Ту-22М3 (ракети Х-22/Х-32)"
        case "iskander":       threatName = "Загроза Іскандер-М"
        default:               threatName = "Повітряна загроза"
        }
        let indicator: String
        if confidence >= 85 {
            indicator = "🔴 Висока ймовірність"
        } else if confidence >= 60 {
            indicator = "🟠 Ймовірна загроза"
        } else {
            indicator = "🟡 Можлива загроза"
        }
        return "\(indicator): \(threatName) (\(region))"
    }
}
