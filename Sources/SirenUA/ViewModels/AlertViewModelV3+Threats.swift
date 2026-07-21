import Foundation

// MARK: - AlertViewModelV3 Threat Fetching & Applying
extension AlertViewModelV3 {

    /// Fetches full threat state from server via GET /api/threats.
    /// Called on: init, every 30s (polling), and on FCM push trigger.
    func fetchThreatState() async {
        guard !isFetching else { return }
        isFetching = true

        do {
            let threats = try await networkManager.fetchThreats(serverURL: threatServerURL)
            applyThreats(threats)
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
        for index in alerts.indices {
            let regionName = alerts[index].name
            guard let threat = threatData[regionName] else { continue }

            let oldThreatLevel = alerts[index].threatLevel
            let newThreatLevel = threat.level == "none" ? nil : threat.level

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
                alerts[index].description = isActive ? "Повітряна тривога!" : "Немає тривоги"
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
        isFirstThreatFetch = false
    }

    func applySingleThreat(region: String, threat: ThreatInfo) {
        guard let index = alerts.firstIndex(where: { $0.name == region }) else { return }
        let oldThreatLevel = alerts[index].threatLevel
        let newThreatLevel = threat.level == "none" ? nil : threat.level

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
            alerts[index].description = isActive ? "Повітряна тривога!" : "Немає тривоги"
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
        errorMessage = nil

        do {
            let liveData = try await networkManager.fetchLiveAlerts()
            applyLiveAlerts(liveData)
            isFirstFetch = false
            updateStats()
        } catch {
            errorMessage = "Помилка оновлення тривог: \(error.localizedDescription)"
            vmLogger.error("Error fetching alerts: \(error.localizedDescription)")
        }

        isLoading = false
        isFetching = false
    }

    func applyLiveAlerts(_ liveData: [String: AerialAlertState]) {
        var newlyAlertedRegionName: String?

        for index in alerts.indices {
            let regionName = alerts[index].name
            guard let state = liveData[regionName] else { continue }

            let isAlertNow = state.alertnow
            let wasActive = alerts[index].isActive
            alerts[index].isActive = isAlertNow
            alerts[index].level = isAlertNow ? 3 : 0
            alerts[index].description = isAlertNow ? "Повітряна тривога!" : "Немає тривоги"
            alerts[index].lastChanged = state.changed

            guard !isFirstFetch else { continue }
            if !wasActive && isAlertNow {
                NotificationManager.shared.sendAlertNotification(for: regionName)
                newlyAlertedRegionName = regionName
            } else if wasActive && !isAlertNow {
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
        let threatName = type == "mig31k" ? "Авіаційна загроза" : "Виявлено цілі"
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
