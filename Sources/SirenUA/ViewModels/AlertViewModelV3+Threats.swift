import Foundation

// MARK: - AlertViewModelV3 Threat Fetching & Applying

extension AlertViewModelV3 {

    /// Fetches full threat state from server via GET /api/threats.
    /// Called on: init, every 30s (polling), and on FCM push trigger.
    /// Сервер вже включає `is_active` (офіційні тривоги) — окремий запит до ubilling не потрібен.
    /// Якщо Threat API недоступний — fallback до `fetchLiveAlerts()` (ubilling).
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
            // Fallback: якщо Threat API недоступний — отримуємо хоча б офіційні тривоги
            await fetchLiveAlerts()
        }
    }

    func applyThreats(_ threatData: [String: ThreatInfo]) {
        objectWillChange.send()
        for index in alerts.indices {
            let regionName = alerts[index].name
            // Крим та Луганщина завжди червоні — не оновлюємо з сервера і не генеруємо сповіщень
            if RegionConstants.isPermanentlyActive(regionName) { continue }
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
                    let typeDesc = ThreatConstants.genitiveDescription(for: threat.type)
                    let title = ThreatConstants.notificationTitle(for: threat.type, confidence: confidence, region: regionName)
                    var body = threat.detail ?? "Виявлено загрозу \(typeDesc)."
                    if let eta = threat.eta, !eta.isEmpty { body += " (Час: \(eta))" }
                    NotificationManager.shared.sendThreatNotification(
                        for: regionName, title: title, body: body,
                        confidence: confidence, isCritical: confidence >= 85
                    )
                }
            } else if oldThreatLevel != nil && newThreatLevel == nil && !alerts[index].isActive {
                if !isFirstThreatFetch {
                    vmLogger.info("Threat cleared for \(regionName) without active alarm — triggering clear notification")
                    NotificationManager.shared.sendClearNotification(for: regionName)
                }
            }
        }

        isFirstThreatFetch = false
    }

    // MARK: Push handling

    func applySingleThreat(region: String, threat: ThreatInfo) {
        if RegionRegistry.isPermanentlyActive(region) { return }
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
                let typeDesc = ThreatConstants.genitiveDescription(for: threat.type)
                let title = ThreatConstants.notificationTitle(for: threat.type, confidence: confidence, region: region)
                var body = threat.detail ?? "Виявлено загрозу \(typeDesc)."
                if let eta = threat.eta, !eta.isEmpty { body += " (Час: \(eta))" }
                NotificationManager.shared.sendThreatNotification(
                    for: region, title: title, body: body,
                    confidence: confidence, isCritical: confidence >= 85
                )
            }
        } else if oldThreatLevel != nil && newThreatLevel == nil && !alerts[index].isActive {
            if !isFirstThreatFetch {
                vmLogger.info("Single threat cleared for \(region) without active alarm — triggering clear notification")
                NotificationManager.shared.sendClearNotification(for: region)
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
            // Крим та Луганщина завжди червоні — не оновлюємо з офіційних тривог
            if RegionConstants.isPermanentlyActive(regionName) { continue }
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
}
