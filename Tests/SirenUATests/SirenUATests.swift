import CoreLocation
import MapKit
import XCTest
@testable import SirenUA

final class MockURLProtocol: URLProtocol {
    static var mockData: Data?
    static var mockResponse: URLResponse?
    static var mockError: Error?
    static var receivedRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.receivedRequests.append(request)
        if let error = MockURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        if let response = MockURLProtocol.mockResponse {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        if let data = MockURLProtocol.mockData {
            client?.urlProtocol(self, didLoad: data)
        }

        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@available(iOS 17.0, *)
final class SirenUATests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.mockData = nil
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.mockError = nil
        MockURLProtocol.receivedRequests = []
        super.tearDown()
    }

    func testLiveAlertParsing() async throws {
        let json = """
        {
            "source": "test",
            "cachedat": "2026-06-27T20:00:00Z",
            "states": {
                "Київська область": {
                    "alertnow": true,
                    "changed": "2026-06-27T19:55:00Z"
                },
                "Львівська область": {
                    "alertnow": false,
                    "changed": "2026-06-27T18:40:00Z"
                }
            }
        }
        """

        MockURLProtocol.mockData = Data(json.utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://ubilling.net.ua/aerialalerts/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let manager = NetworkManager(session: makeMockSession())
        let alerts = try await manager.fetchLiveAlerts()

        XCTAssertEqual(alerts["Київська область"]?.alertnow, true)
        XCTAssertEqual(alerts["Київська область"]?.changed, "2026-06-27T19:55:00Z")
        XCTAssertEqual(alerts["Львівська область"]?.alertnow, false)
        XCTAssertEqual(alerts["Львівська область"]?.changed, "2026-06-27T18:40:00Z")
        XCTAssertEqual(alerts.count, 2)
    }

    func testInvalidStatusCodeThrows() async {
        MockURLProtocol.mockData = Data()
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://ubilling.net.ua/aerialalerts/")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        let manager = NetworkManager(session: makeMockSession())

        do {
            _ = try await manager.fetchLiveAlerts()
            XCTFail("Expected invalid response error")
        } catch let error as NetworkError {
            XCTAssertEqual(error.localizedDescription, NetworkError.invalidResponse(statusCode: 500).localizedDescription)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchLiveAlertsSetsExpectedRequestHeaders() async throws {
        MockURLProtocol.mockData = Data("""
        {
            "source": "test",
            "cachedat": "2026-06-27T20:00:00Z",
            "states": {}
        }
        """.utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://ubilling.net.ua/aerialalerts/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let manager = NetworkManager(session: makeMockSession())
        _ = try await manager.fetchLiveAlerts()

        let request = try XCTUnwrap(MockURLProtocol.receivedRequests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://ubilling.net.ua/aerialalerts/")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "ios-sirenua/4.2")
    }

    func testMalformedJSONThrowsInvalidResponse() async {
        MockURLProtocol.mockData = Data("not-json".utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            url: URL(string: "https://ubilling.net.ua/aerialalerts/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let manager = NetworkManager(session: makeMockSession())

        do {
            _ = try await manager.fetchLiveAlerts()
            XCTFail("Expected invalid response error")
        } catch let error as NetworkError {
            switch error {
            case .decodingFailed:
                // Success: correct error type
                break
            default:
                XCTFail("Expected decodingFailed, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTransportErrorIsPropagated() async {
        MockURLProtocol.mockError = URLError(.notConnectedToInternet)

        let manager = NetworkManager(session: makeMockSession())

        do {
            _ = try await manager.fetchLiveAlerts()
            XCTFail("Expected transport error")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAlertRegionCodableRoundTripPreservesCoordinates() throws {
        let region = AlertRegion(
            id: 7,
            name: "Київська область",
            isActive: true,
            level: 3,
            description: "Повітряна тривога!",
            coordinate: CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)
        )

        let data = try JSONEncoder().encode(region)
        let decoded = try JSONDecoder().decode(AlertRegion.self, from: data)

        XCTAssertEqual(decoded.id, region.id)
        XCTAssertEqual(decoded.name, region.name)
        XCTAssertEqual(decoded.isActive, region.isActive)
        XCTAssertEqual(decoded.level, region.level)
        XCTAssertEqual(decoded.description, region.description)
        XCTAssertEqual(decoded.coordinate.latitude, region.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(decoded.coordinate.longitude, region.coordinate.longitude, accuracy: 0.0001)
    }

    func testAlertRegionEquality() {
        let first = AlertRegion(
            id: 1,
            name: "Київська область",
            isActive: true,
            level: 3,
            description: "Повітряна тривога!",
            coordinate: CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)
        )
        let identical = AlertRegion(
            id: 1,
            name: "Київська область",
            isActive: true,
            level: 3,
            description: "Повітряна тривога!",
            coordinate: CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)
        )
        let different = AlertRegion(
            id: 1,
            name: "Львівська область",
            isActive: false,
            level: 0,
            description: "Немає тривоги",
            coordinate: CLLocationCoordinate2D(latitude: 49.8397, longitude: 24.0297)
        )

        XCTAssertEqual(first, identical)
        XCTAssertNotEqual(first, different)
        XCTAssertEqual(first.id, different.id)
    }

    func testAlertRegionIconsMatchLevels() {
        XCTAssertEqual(makeRegion(level: 0).icon, "info.circle.fill")
        XCTAssertEqual(makeRegion(level: 1).icon, "exclamationmark.triangle.fill")
        XCTAssertEqual(makeRegion(level: 2).icon, "bell.fill")
        XCTAssertEqual(makeRegion(level: 3).icon, "speaker.wave.3.fill")
    }

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeRegion(level: Int) -> AlertRegion {
        AlertRegion(
            id: level,
            name: "Тестова область",
            isActive: level > 0,
            level: level,
            description: "Тест",
            coordinate: CLLocationCoordinate2D(latitude: 50.0, longitude: 30.0)
        )
    }

    func testThreatInfoDecodingWithNewAIFields() throws {
        let json = """
        {
            "level": "medium",
            "type": "shahed",
            "detail": "БпЛА курсом на Київщину",
            "since": "2026-07-07T12:00:00Z",
            "confidence": 85,
            "eta": "~1-2 год",
            "is_predictive": true
        }
        """
        
        let data = Data(json.utf8)
        let threat = try JSONDecoder().decode(ThreatInfo.self, from: data)
        
        XCTAssertEqual(threat.level, "medium")
        XCTAssertEqual(threat.type, "shahed")
        XCTAssertEqual(threat.detail, "БпЛА курсом на Київщину")
        XCTAssertEqual(threat.since, "2026-07-07T12:00:00Z")
        XCTAssertEqual(threat.confidence, 85)
        XCTAssertEqual(threat.eta, "~1-2 год")
        XCTAssertEqual(threat.is_predictive, true)
    }

    func testDynamicETACalculations() throws {
        // Formulate an ISO string 10 minutes ago
        let tenMinAgo = Date().addingTimeInterval(-605)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceStr = formatter.string(from: tenMinAgo)
        
        let threat = SingleThreatInfo(
            threat_id: "test_t1",
            level: "high",
            type: "shahed",
            detail: "Test Detail",
            since: sinceStr,
            confidence: 90,
            eta: "~25 хв",
            is_predictive: false,
            is_test: false,
            group_id: nil,
            origin_latitude: 50.0,
            origin_longitude: 30.0,
            last_checkpoint_latitude: nil,
            last_checkpoint_longitude: nil
        )
        
        XCTAssertEqual(threat.elapsedMinutes, 10)
        XCTAssertEqual(threat.dynamicETA, "до 15 хв")

        // Test Red zone (high level) expired ETA -> "в області"
        let thirtyMinAgoStr = formatter.string(from: Date().addingTimeInterval(-1805))
        let redExpiredThreat = SingleThreatInfo(
            threat_id: "test_red_exp",
            level: "high",
            type: "cruise_missile",
            detail: "Test Red",
            since: thirtyMinAgoStr,
            confidence: 95,
            eta: "~20 хв",
            is_predictive: false
        )
        XCTAssertEqual(redExpiredThreat.dynamicETA, "в області")

        // Test Yellow zone (medium / predictive) expired ETA -> "на підльоті"
        let yellowExpiredThreat = SingleThreatInfo(
            threat_id: "test_yellow_exp",
            level: "medium",
            type: "shahed",
            detail: "Test Yellow",
            since: thirtyMinAgoStr,
            confidence: 80,
            eta: "~20 хв",
            is_predictive: true
        )
        XCTAssertEqual(yellowExpiredThreat.dynamicETA, "на підльоті")

        // Test KAB in yellow zone (low level) expired ETA -> "на підльоті"
        let kabYellowThreat = SingleThreatInfo(
            threat_id: "test_kab_yellow",
            level: "low",
            type: "kab",
            detail: "Test KAB",
            since: thirtyMinAgoStr,
            confidence: 75,
            eta: "~5 хв",
            is_predictive: true
        )
        XCTAssertEqual(kabYellowThreat.dynamicETA, "на підльоті")
    }

    func testDynamicDistanceCalculations() throws {
        // Formulate an ISO string 15 minutes ago
        let fifteenMinAgo = Date().addingTimeInterval(-905)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceStr = formatter.string(from: fifteenMinAgo)
        
        let threat = SingleThreatInfo(
            threat_id: "test_t2",
            level: "high",
            type: "shahed",
            detail: "Test Detail",
            since: sinceStr,
            confidence: 90,
            eta: "~45 хв",
            is_predictive: false,
            is_test: false,
            group_id: nil,
            origin_latitude: 50.0,
            origin_longitude: 30.0,
            last_checkpoint_latitude: nil,
            last_checkpoint_longitude: nil
        )
        
        XCTAssertEqual(threat.elapsedMinutes, 15)
        
        let originalLine = "Відстань: ~120 км"
        let dynamicLine = threat.dynamicDistance(from: originalLine)
        
        // speed = 120 / 45 = 2.666... km/min
        // remaining = 120 - 2.666... * 15 = 120 - 40 = 80 km
        XCTAssertEqual(dynamicLine, "Відстань: ~80 км")
    }

    func testNotificationSettingsToggles() throws {
        let defaults = UserDefaults.standard

        // Backup current values
        let oldNotif = defaults.object(forKey: "notificationsEnabled")
        let oldCrit = defaults.object(forKey: "criticalAlertsEnabled")
        let oldAlarmMute = defaults.object(forKey: "muteAlarmsSound")
        let oldThreatMute = defaults.object(forKey: "muteThreatsSound")
        let oldClearMute = defaults.object(forKey: "muteClearSound")
        let oldVib = defaults.object(forKey: "vibrationEnabled")

        defer {
            defaults.setValue(oldNotif, forKey: "notificationsEnabled")
            defaults.setValue(oldCrit, forKey: "criticalAlertsEnabled")
            defaults.setValue(oldAlarmMute, forKey: "muteAlarmsSound")
            defaults.setValue(oldThreatMute, forKey: "muteThreatsSound")
            defaults.setValue(oldClearMute, forKey: "muteClearSound")
            defaults.setValue(oldVib, forKey: "vibrationEnabled")
        }

        // 1. notificationsEnabled toggle
        defaults.set(false, forKey: "notificationsEnabled")
        XCTAssertFalse(defaults.bool(forKey: "notificationsEnabled"))

        defaults.set(true, forKey: "notificationsEnabled")
        XCTAssertTrue(defaults.bool(forKey: "notificationsEnabled"))

        // 2. criticalAlertsEnabled toggle
        defaults.set(false, forKey: "criticalAlertsEnabled")
        XCTAssertFalse(defaults.bool(forKey: "criticalAlertsEnabled"))

        defaults.set(true, forKey: "criticalAlertsEnabled")
        XCTAssertTrue(defaults.bool(forKey: "criticalAlertsEnabled"))

        // 3. muteAlarmsSound toggle
        defaults.set(true, forKey: "muteAlarmsSound")
        XCTAssertTrue(defaults.bool(forKey: "muteAlarmsSound"))

        defaults.set(false, forKey: "muteAlarmsSound")
        XCTAssertFalse(defaults.bool(forKey: "muteAlarmsSound"))

        // 4. muteThreatsSound toggle
        defaults.set(true, forKey: "muteThreatsSound")
        XCTAssertTrue(defaults.bool(forKey: "muteThreatsSound"))

        defaults.set(false, forKey: "muteThreatsSound")
        XCTAssertFalse(defaults.bool(forKey: "muteThreatsSound"))

        // 5. muteClearSound toggle
        defaults.set(true, forKey: "muteClearSound")
        XCTAssertTrue(defaults.bool(forKey: "muteClearSound"))

        defaults.set(false, forKey: "muteClearSound")
        XCTAssertFalse(defaults.bool(forKey: "muteClearSound"))

        // 6. muteThreatClearSound toggle
        defaults.set(true, forKey: "muteThreatClearSound")
        XCTAssertTrue(defaults.bool(forKey: "muteThreatClearSound"))

        defaults.set(false, forKey: "muteThreatClearSound")
        XCTAssertFalse(defaults.bool(forKey: "muteThreatClearSound"))

        // 7. vibrationEnabled toggle
        defaults.set(false, forKey: "vibrationEnabled")
        XCTAssertFalse(defaults.bool(forKey: "vibrationEnabled"))

        defaults.set(true, forKey: "vibrationEnabled")
        XCTAssertTrue(defaults.bool(forKey: "vibrationEnabled"))

        // 8. allUkraineTrajectoriesEnabled toggle (default: false)
        defaults.set(true, forKey: "allUkraineTrajectoriesEnabled")
        XCTAssertTrue(defaults.bool(forKey: "allUkraineTrajectoriesEnabled"))

        defaults.set(false, forKey: "allUkraineTrajectoriesEnabled")
        XCTAssertFalse(defaults.bool(forKey: "allUkraineTrajectoriesEnabled"))
    }

    func testAllUkraineTrajectoriesToggleAndVisibility() {
        let settings = NotificationSettings.shared
        settings.allRegionsTracked = false
        settings.trackedRegionsString = "м. Київ;Львівська область"
        settings.allUkraineTrajectoriesEnabled = false

        // 1. By default, allUkraineTrajectoriesEnabled is false
        // Tracked regions: м. Київ -> should show trajectory
        let kyivTracked = settings.isTracked("м. Київ")
        XCTAssertTrue(kyivTracked)
        let kyivShowTrajectoryDefault = true && (settings.allUkraineTrajectoriesEnabled || kyivTracked)
        XCTAssertTrue(kyivShowTrajectoryDefault)

        // Untracked region: Одеська область -> should NOT show trajectory when toggle is false
        let odesaTracked = settings.isTracked("Одеська область")
        XCTAssertFalse(odesaTracked)
        let odesaShowTrajectoryDefault = true && (settings.allUkraineTrajectoriesEnabled || odesaTracked)
        XCTAssertFalse(odesaShowTrajectoryDefault)

        // 2. When allUkraineTrajectoriesEnabled is enabled -> both should show trajectories
        settings.allUkraineTrajectoriesEnabled = true
        let odesaShowTrajectoryEnabled = true && (settings.allUkraineTrajectoriesEnabled || odesaTracked)
        XCTAssertTrue(odesaShowTrajectoryEnabled)
        let kyivShowTrajectoryEnabled = true && (settings.allUkraineTrajectoriesEnabled || kyivTracked)
        XCTAssertTrue(kyivShowTrajectoryEnabled)

        // 3. When isPremium is false -> no trajectories regardless of toggle
        let isPremium = false
        let odesaNonPremium = isPremium && (settings.allUkraineTrajectoriesEnabled || odesaTracked)
        XCTAssertFalse(odesaNonPremium)

        // Cleanup
        settings.allUkraineTrajectoriesEnabled = false
        settings.allRegionsTracked = true
        settings.trackedRegionsString = ""
    }

    func testNotificationSoundConfigAndCriticalPolicies() {
        let settings = NotificationSettings.shared
        settings.notificationsEnabled = true
        settings.criticalAlertsEnabled = true
        settings.muteAlarmsSound = false
        settings.muteClearSound = false
        settings.muteThreatsSound = false
        settings.muteThreatClearSound = false
        settings.vibrationEnabled = true

        // 1. Official Alarm -> siren.wav, relevance = 1.0, timeSensitive (with criticalAlertsEnabled)
        let alarmConfig = NotificationManager.shared.soundConfig(for: .alarm)
        XCTAssertEqual(alarmConfig.soundName, "siren.wav")
        XCTAssertEqual(alarmConfig.level, .timeSensitive)
        XCTAssertEqual(alarmConfig.relevance, 1.0)

        // 2. Official Clear -> vidbiy.wav, relevance = 0.5
        let clearConfig = NotificationManager.shared.soundConfig(for: .clear)
        XCTAssertEqual(clearConfig.soundName, "vidbiy.wav")
        XCTAssertEqual(clearConfig.level, .timeSensitive)
        XCTAssertEqual(clearConfig.relevance, 0.5)

        // 3. AI Threat -> warning.wav, relevance = 0.8 (high confidence), timeSensitive, NEVER critical
        let threatConfig = NotificationManager.shared.soundConfig(for: .threat, confidence: 90)
        XCTAssertEqual(threatConfig.soundName, "warning.wav")
        XCTAssertEqual(threatConfig.level, .timeSensitive)
        XCTAssertEqual(threatConfig.relevance, 0.8)

        // 4. AI Threat Clear -> clearance.wav, relevance = 0.3, active level
        let threatClearConfig = NotificationManager.shared.soundConfig(for: .threatClear)
        XCTAssertEqual(threatClearConfig.soundName, "clearance.wav")
        XCTAssertEqual(threatClearConfig.level, .active)
        XCTAssertEqual(threatClearConfig.relevance, 0.3)

        // 5. Test Muting Specific Sounds
        settings.muteAlarmsSound = true
        XCTAssertEqual(NotificationManager.shared.soundConfig(for: .alarm).soundName, "")
        settings.muteAlarmsSound = false

        settings.muteThreatsSound = true
        XCTAssertEqual(NotificationManager.shared.soundConfig(for: .threat).soundName, "")
        settings.muteThreatsSound = false

        settings.muteClearSound = true
        XCTAssertEqual(NotificationManager.shared.soundConfig(for: .clear).soundName, "")
        settings.muteClearSound = false

        settings.muteThreatClearSound = true
        XCTAssertEqual(NotificationManager.shared.soundConfig(for: .threatClear).soundName, "")
        settings.muteThreatClearSound = false

        // 6. Test Master Switch
        settings.notificationsEnabled = false
        XCTAssertEqual(NotificationManager.shared.soundConfig(for: .alarm).soundName, "")
        XCTAssertEqual(NotificationManager.shared.soundConfig(for: .threat).soundName, "")
        XCTAssertEqual(NotificationManager.shared.soundConfig(for: .clear).soundName, "")
        XCTAssertEqual(NotificationManager.shared.soundConfig(for: .threatClear).soundName, "")
        XCTAssertFalse(settings.shouldVibrate)
        settings.notificationsEnabled = true
    }

    func testPremiumGatekeeperCanAccess() async {
        await MainActor.run {
            let gatekeeper = PremiumGatekeeper.shared
            
            // Force premium status off for test
            UserDefaults.standard.set(true, forKey: "debugPremiumMuted")
            UserDefaults.standard.set(false, forKey: "debugPremiumEnabled")
            gatekeeper.updatePremiumStatus()
            XCTAssertFalse(gatekeeper.canAccess(.chronology))
            XCTAssertFalse(gatekeeper.canAccess(.yellowZones))
            XCTAssertFalse(gatekeeper.canAccess(.trajectories))
            XCTAssertFalse(gatekeeper.canAccess(.threatToggles))
            XCTAssertFalse(gatekeeper.canAccess(.threatDetails))
            
            // Force premium status on for test
            UserDefaults.standard.set(false, forKey: "debugPremiumMuted")
            UserDefaults.standard.set(true, forKey: "debugPremiumEnabled")
            gatekeeper.updatePremiumStatus()
            XCTAssertTrue(gatekeeper.canAccess(.chronology))
            XCTAssertTrue(gatekeeper.canAccess(.yellowZones))
            XCTAssertTrue(gatekeeper.canAccess(.trajectories))
            XCTAssertTrue(gatekeeper.canAccess(.threatToggles))
            XCTAssertTrue(gatekeeper.canAccess(.threatDetails))
        }
    }

    func testYellowZonePolicyFilterActiveThreatRegions() {
        let threatRegion = AlertRegion(
            id: 1,
            name: "Київська область",
            isActive: false,
            level: 2,
            description: "БпЛА",
            coordinate: CLLocationCoordinate2D(latitude: 50.45, longitude: 30.52),
            threatLevel: "medium",
            threatType: "shahed"
        )
        let regionPoly = RegionPolygon(
            id: "kyiv",
            name: "Kyiv Oblast",
            nameUK: "Київська область",
            polygons: [],
            mkPolygons: [],
            identifiablePolygons: [],
            center: CLLocationCoordinate2D(latitude: 50.45, longitude: 30.52)
        )
        let alertsDict = ["Київська область": threatRegion]

        // Non-premium filter should return empty array
        let nonPremiumResult = YellowZonePolicy.filterActiveThreatRegions(
            allRegions: [regionPoly],
            alertsDict: alertsDict,
            isPremium: false
        )
        XCTAssertTrue(nonPremiumResult.isEmpty)

        // Premium filter should return threat region
        let premiumResult = YellowZonePolicy.filterActiveThreatRegions(
            allRegions: [regionPoly],
            alertsDict: alertsDict,
            isPremium: true
        )
        XCTAssertEqual(premiumResult.count, 1)
        XCTAssertEqual(premiumResult.first?.nameUK, "Київська область")
    }

    func testShelterItemDecodingAndTypeDescriptions() throws {
        let json = """
        {
            "count": 4,
            "radius_m": 2000,
            "total_in_db": 4,
            "shelters": [
                {
                    "id": "s_1",
                    "name": "Бомбосховище №1",
                    "address": "вул. Хрещатик 1",
                    "lat": 50.4501,
                    "lon": 30.5234,
                    "distance_m": 350.0,
                    "type": "bomb_shelter",
                    "capacity": 500,
                    "accessible": true,
                    "source": "osm"
                },
                {
                    "id": "s_2",
                    "name": "Підземний паркінг",
                    "address": "пл. Спортивна 1",
                    "lat": 50.4385,
                    "lon": 30.5230,
                    "distance_m": 1200.0,
                    "type": "underground_parking",
                    "capacity": 800,
                    "accessible": true,
                    "source": "osm"
                },
                {
                    "id": "s_3",
                    "name": "Станція метро Майдан",
                    "address": "Майдан Незалежності",
                    "lat": 50.4505,
                    "lon": 30.5230,
                    "distance_m": 450.0,
                    "type": "metro",
                    "capacity": 3000,
                    "accessible": true,
                    "source": "osm"
                },
                {
                    "id": "s_4",
                    "name": "Бункер цивільного захисту",
                    "address": "вул. Банкова",
                    "lat": 50.4460,
                    "lon": 30.5280,
                    "distance_m": 850.0,
                    "type": "bunker",
                    "capacity": 200,
                    "accessible": false,
                    "source": "osm"
                }
            ]
        }
        """

        let response = try JSONDecoder().decode(ShelterResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.count, 4)
        XCTAssertEqual(response.shelters.count, 4)

        let s1 = response.shelters[0]
        XCTAssertEqual(s1.typeDescription, "Бомбосховище")
        XCTAssertEqual(s1.distanceText, "350 м")
        XCTAssertEqual(s1.iconName, "shield.fill")

        let s2 = response.shelters[1]
        XCTAssertEqual(s2.typeDescription, "Підземний паркінг")
        XCTAssertEqual(s2.distanceText, "1.2 км")
        XCTAssertEqual(s2.iconName, "parkingsign.circle.fill")

        let s3 = response.shelters[2]
        XCTAssertEqual(s3.typeDescription, "Станція метро")
        XCTAssertEqual(s3.iconName, "tram.fill")

        let s4 = response.shelters[3]
        XCTAssertEqual(s4.typeDescription, "Бункер")
        XCTAssertEqual(s4.iconName, "shield.checkered")
    }

    func testShelterKeywordsExclusionFilterLogic() {
        let excludedKeywords = [
            "дощ", "зупинка", "навіс", "альтанка", "павільйон", "тент",
            "палатка", "павіліон", "пляж", "кафе", "ресторан", "маф", "кіоск", "мангал",
            "rain", "bus stop", "gazebo", "awning", "tent", "transit", "stop", "platform"
        ]

        let testNames: [(name: String, shouldExclude: Bool)] = [
            ("Зупинка автобуса №24", true),
            ("Навіс від дощу", true),
            ("Альтанка в парку", true),
            ("Кафе біля пляжу", true),
            ("Бомбосховище №14", false),
            ("Підземний паркінг ТРЦ", false),
            ("Станція метро Хрещатик", false),
            ("Протирадіаційне укриття", false),
            ("Бункер цивільного захисту", false)
        ]

        for test in testNames {
            let nameLower = test.name.lowercased()
            let isUndergroundParking = nameLower.contains("паркінг") || nameLower.contains("парковка")
            let isSubway = nameLower.contains("метро") || nameLower.contains("subway")
            
            var isExcluded = false
            if !isUndergroundParking && !isSubway {
                isExcluded = excludedKeywords.contains { nameLower.contains($0) }
            }

            XCTAssertEqual(
                isExcluded,
                test.shouldExclude,
                "Failed exclusion check for '\(test.name)': expected \(test.shouldExclude), got \(isExcluded)"
            )
        }
    }

    func testShelterPanelDismissalAndAutoReset() async {
        let mapVM = await MainActor.run { () -> MapViewModel in
            let vm = MapViewModel()
            vm.selectedTab = 2
            vm.showShelterPanel(autoHideAfter: 0.05)
            XCTAssertTrue(vm.isShelterPanelVisible)
            return vm
        }

        try? await Task.sleep(nanoseconds: 250_000_000)

        await MainActor.run {
            XCTAssertFalse(mapVM.isShelterPanelVisible)
            XCTAssertEqual(mapVM.selectedTab, 0)

            mapVM.selectedTab = 2
            mapVM.isShelterPanelVisible = true
            mapVM.hideShelterPanel()
            XCTAssertFalse(mapVM.isShelterPanelVisible)
            XCTAssertEqual(mapVM.selectedTab, 0)
        }
    }

    func testLocationManagerPermissionsAndResolution() async {
        await MainActor.run {
            let locManager = LocationManager.shared
            XCTAssertNotNil(locManager.authorizationStatus)
            if locManager.authorizationStatus == .denied || locManager.authorizationStatus == .restricted {
                XCTAssertTrue(locManager.isLocationDenied)
                XCTAssertFalse(locManager.isLocationAuthorized)
            }
            _ = locManager.hasLiveLocationFix
            _ = locManager.isLocationInitialized
        }

        let coord = await LocationManager.shared.resolveUserCoordinate(timeoutSeconds: 0.1, forceFresh: false)
        if let location = await MainActor.run(body: { LocationManager.shared.location }) {
            XCTAssertEqual(coord?.latitude, location.coordinate.latitude)
            XCTAssertEqual(coord?.longitude, location.coordinate.longitude)
        }
    }

    func testShelterRadiusFilterAndDistanceExclusionLogic() {
        let preferredRadiusMeters = 1500.0 // 1.5 km
        let maxSearchRadiusMeters = 5000.0 // 5.0 km

        let shelters = [
            ShelterItem(id: "1", name: "Укриття поруч", address: nil, lat: 50.4520, lon: 30.5250, distance_m: 300.0, type: "bomb_shelter", capacity: 100, accessible: true, source: "osm"),
            ShelterItem(id: "2", name: "Укриття в межах 1.2км", address: nil, lat: 50.4580, lon: 30.5300, distance_m: 1200.0, type: "bomb_shelter", capacity: 200, accessible: true, source: "osm"),
            ShelterItem(id: "3", name: "Укриття на відстані 3.5км", address: nil, lat: 50.4800, lon: 30.5500, distance_m: 3500.0, type: "bomb_shelter", capacity: 300, accessible: true, source: "osm"),
            ShelterItem(id: "4", name: "Укриття в іншому місті (350км)", address: nil, lat: 48.0000, lon: 35.0000, distance_m: 350_000.0, type: "metro", capacity: 5000, accessible: true, source: "osm")
        ]

        // 1. When items in preferred radius exist:
        let preferred = shelters.filter { $0.distance_m <= preferredRadiusMeters }
        XCTAssertEqual(preferred.count, 2)
        XCTAssertEqual(preferred.min(by: { $0.distance_m < $1.distance_m })?.name, "Укриття поруч")

        // 2. When only items within maxSearchRadius exist (preferred is empty):
        let distantSubset = [shelters[2], shelters[3]]
        let preferredDistant = distantSubset.filter { $0.distance_m <= preferredRadiusMeters }
        XCTAssertTrue(preferredDistant.isEmpty)

        let withinMax = distantSubset.filter { $0.distance_m <= maxSearchRadiusMeters }
        XCTAssertEqual(withinMax.count, 1)
        XCTAssertEqual(withinMax.first?.name, "Укриття на відстані 3.5км")

        // 3. When all items are far away (exceeding maxSearchRadiusMeters, e.g. 350km):
        let farAwaySubset = [shelters[3]]
        let validNearby = farAwaySubset.filter { $0.distance_m <= maxSearchRadiusMeters }
        XCTAssertTrue(validNearby.isEmpty, "Shelters 350km away must be strictly excluded!")
    }

    func testProgressiveShelterCascadeForRuralVillages() {
        // Simulating user in Uhersko village where local shelter is 350m (Lyceum) and district shelter is 5.4km (Stryi)
        let lyceumShelter = ShelterItem(id: "uhersko_1", name: "Угерський ліцей (Найпростіше укриття)", address: "вул. Івана Франка 2", lat: 49.3005, lon: 23.8966, distance_m: 0.0, type: "school_shelter", capacity: 350, accessible: true, source: "gov", is_primary: false, is_night_accessible: false, is_vehicle_accessible: false)
        let stryiShelter = ShelterItem(id: "stryi_1", name: "Стрийська лікарня (Сховище)", address: "вул. Басараб 15, м. Стрий", lat: 49.2620, lon: 23.8650, distance_m: 5400.0, type: "radiation_shelter", capacity: 600, accessible: true, source: "gov", is_primary: true, is_night_accessible: true, is_vehicle_accessible: false)

        let targetRadiusMeters = 1500.0
        let localExtendedMeters = 6000.0
        let regionalExtendedMeters = 15000.0

        // Case A: Immediate local shelter found
        let listWithLyceum = [lyceumShelter, stryiShelter]
        let strictFound = listWithLyceum.filter { $0.distance_m <= targetRadiusMeters }
        XCTAssertEqual(strictFound.count, 1)
        XCTAssertEqual(strictFound.first?.name, "Угерський ліцей (Найпростіше укриття)")
        XCTAssertEqual(strictFound.first?.category, .secondary)

        // Case B: Only distant district center found (e.g. Stryi at 5.4km)
        let listOnlyStryi = [stryiShelter]
        let strictEmpty = listOnlyStryi.filter { $0.distance_m <= targetRadiusMeters }
        XCTAssertTrue(strictEmpty.isEmpty)

        let localExt = listOnlyStryi.filter { $0.distance_m <= localExtendedMeters }
        XCTAssertEqual(localExt.count, 1)
        XCTAssertEqual(localExt.first?.name, "Стрийська лікарня (Сховище)")
        XCTAssertEqual(localExt.first?.category, .primary)

        // Case C: District regional fallback
        let regionalExt = listOnlyStryi.filter { $0.distance_m <= regionalExtendedMeters }
        XCTAssertEqual(regionalExt.count, 1)
    }

    func testEmulatedKyivMallParkingSearch_NightScenario() {
        // 1. Emulated Coordinate: Kyiv Vinogradar near Retroville Mall (50.5050, 30.4150)
        let retrovilleParking = ShelterItem(
            id: "m1",
            name: "Підземний та відкритий паркінг ТРЦ «Retroville» (Цілодобово для авто)",
            address: "просп. Правди, 47",
            lat: 50.5052,
            lon: 30.4152,
            distance_m: 30.0,
            type: "mall_parking",
            capacity: 3200,
            accessible: true,
            source: "gov",
            is_primary: false,
            is_night_accessible: true,
            is_vehicle_accessible: true
        )

        let schoolShelter = ShelterItem(
            id: "s1",
            name: "Школа №243 (Найпростіше укриття)",
            address: "вул. Новомостицька, 10",
            lat: 50.5020,
            lon: 30.4200,
            distance_m: 450.0,
            type: "school_shelter",
            capacity: 500,
            accessible: true,
            source: "gov",
            is_primary: false,
            is_night_accessible: false,
            is_vehicle_accessible: false
        )

        let distantMetroSyrets = ShelterItem(
            id: "m_syr",
            name: "Станція метро «Сирець»",
            address: "вул. Щусєва",
            lat: 50.4760,
            lon: 30.4310,
            distance_m: 3500.0,
            type: "metro",
            capacity: 4000,
            accessible: true,
            source: "gov",
            is_primary: true,
            is_night_accessible: true,
            is_vehicle_accessible: false
        )

        let availableShelters = [retrovilleParking, schoolShelter, distantMetroSyrets]
        let walkingRadius = 1500.0

        // In 1.5km walking radius: No primary (Metro is at 3.5km). Secondary options exist (Retroville & School).
        let inRadius = availableShelters.filter { $0.distance_m <= walkingRadius }
        let primaryInRadius = inRadius.filter { $0.category == .primary }
        let secondaryInRadius = inRadius.filter { $0.category == .secondary }

        XCTAssertTrue(primaryInRadius.isEmpty, "No primary metro shelter should be within 1.5km on Vinogradar")
        XCTAssertEqual(secondaryInRadius.count, 2)

        // Select closest secondary with vehicle / 24/7 night access
        let sortedSecondary = secondaryInRadius.sorted { (a, b) in
            if a.isVehicleAccessible != b.isVehicleAccessible {
                return a.isVehicleAccessible
            }
            return a.distance_m < b.distance_m
        }

        let selected = sortedSecondary.first!
        XCTAssertEqual(selected.id, "m1")
        XCTAssertEqual(selected.shelterType, .mallParking)
        XCTAssertTrue(selected.isNightAccessible, "Mall parking must be accessible at night for vehicle shelter")
        XCTAssertTrue(selected.isVehicleAccessible, "Mall parking must allow direct car sheltering")
        XCTAssertEqual(selected.shelterType.badgeText, "Паркінг ТРЦ • Авто")
    }

    func testEmulatedKyivCenterMetroPriority_PrimaryOverSecondary() {
        // 2. Emulated Coordinate: Kyiv Khreshchatyk (50.4475, 30.5230)
        let metroKhreshchatyk = ShelterItem(
            id: "khr_metro",
            name: "Станція метро «Хрещатик» (Укриття)",
            address: "вул. Хрещатик, 19",
            lat: 50.4475,
            lon: 30.5230,
            distance_m: 10.0,
            type: "metro",
            capacity: 5000,
            accessible: true,
            source: "gov",
            is_primary: true,
            is_night_accessible: true,
            is_vehicle_accessible: false
        )

        let gulliverParking = ShelterItem(
            id: "gul_park",
            name: "Підземний паркінг ТРЦ «Gulliver» (Укриття / Авто)",
            address: "Спортивна площа, 1A",
            lat: 50.4385,
            lon: 30.5230,
            distance_m: 900.0,
            type: "mall_parking",
            capacity: 2500,
            accessible: true,
            source: "gov",
            is_primary: false,
            is_night_accessible: true,
            is_vehicle_accessible: true
        )

        let available = [gulliverParking, metroKhreshchatyk]
        let radius = 1500.0

        let inRadius = available.filter { $0.distance_m <= radius }
        let primaryInRadius = inRadius.filter { $0.category == .primary }

        // Primary official shelter exists in radius -> Must pick Metro (Primary) over Mall Parking
        XCTAssertFalse(primaryInRadius.isEmpty)
        let selected = primaryInRadius.min(by: { $0.distance_m < $1.distance_m })!
        XCTAssertEqual(selected.id, "khr_metro")
        XCTAssertEqual(selected.category, .primary)
        XCTAssertEqual(selected.shelterType, .metro)
        XCTAssertTrue(selected.isNightAccessible)
    }

    func testEmulatedGPSLocationsNationwide_AcrossAllRegions() {
        // Multi-point simulated GPS search testing across 6 major hubs and rural sectors
        struct EmulatedScenario {
            let cityName: String
            let coordinate: CLLocationCoordinate2D
            let candidateShelters: [ShelterItem]
            let expectedSelectedId: String
            let expectedCategory: ShelterCategory
            let shouldShowWarning: Bool
        }

        let scenarios: [EmulatedScenario] = [
            // 1. Lviv Victoria Gardens (Shopping mall parking fallback when no primary in strict 1km walking radius)
            EmulatedScenario(
                cityName: "Львів (Південь)",
                coordinate: CLLocationCoordinate2D(latitude: 49.8075, longitude: 23.9780),
                candidateShelters: [
                    ShelterItem(id: "lv_vg", name: "Підземний паркінг ТРЦ «Victoria Gardens»", address: "вул. Кульпарківська, 226А", lat: 49.8075, lon: 23.9780, distance_m: 100.0, type: "mall_parking", capacity: 1500, accessible: true, source: "gov", is_primary: false, is_night_accessible: true, is_vehicle_accessible: true),
                    ShelterItem(id: "lv_lnu", name: "Каземати ЛНУ", address: "вул. Університетська", lat: 49.8403, lon: 24.0222, distance_m: 5200.0, type: "school_shelter", capacity: 2000, accessible: true, source: "gov", is_primary: true, is_night_accessible: true, is_vehicle_accessible: false)
                ],
                expectedSelectedId: "lv_vg",
                expectedCategory: .secondary,
                shouldShowWarning: true
            ),

            // 2. Dnipro Centre (Primary Metro station priority)
            EmulatedScenario(
                cityName: "Дніпро (Центр)",
                coordinate: CLLocationCoordinate2D(latitude: 48.4647, longitude: 35.0462),
                candidateShelters: [
                    ShelterItem(id: "dn_metro", name: "Станція метро «Вокзальна»", address: "Вокзальна площа", lat: 48.4647, lon: 35.0462, distance_m: 200.0, type: "metro", capacity: 3000, accessible: true, source: "gov", is_primary: true, is_night_accessible: true, is_vehicle_accessible: false),
                    ShelterItem(id: "dn_most", name: "Паркінг МОСТ-Сіті", address: "вул. Глінки, 2", lat: 48.4670, lon: 35.0490, distance_m: 150.0, type: "mall_parking", capacity: 1000, accessible: true, source: "gov", is_primary: false, is_night_accessible: true, is_vehicle_accessible: true)
                ],
                expectedSelectedId: "dn_metro",
                expectedCategory: .primary,
                shouldShowWarning: false
            ),

            // 3. Kharkiv Svobody (Primary Karazin bunker)
            EmulatedScenario(
                cityName: "Харків (Площа Свободи)",
                coordinate: CLLocationCoordinate2D(latitude: 50.0056, longitude: 36.2278),
                candidateShelters: [
                    ShelterItem(id: "kh_karazin", name: "Укриття ХНУ ім. Каразіна", address: "пл. Свободи, 4", lat: 50.0056, lon: 36.2278, distance_m: 80.0, type: "school_shelter", capacity: 3000, accessible: true, source: "gov", is_primary: true, is_night_accessible: true, is_vehicle_accessible: false)
                ],
                expectedSelectedId: "kh_karazin",
                expectedCategory: .primary,
                shouldShowWarning: false
            ),

            // 4. Odesa Port Area (Primary Port bunker)
            EmulatedScenario(
                cityName: "Одеса (Митна площа)",
                coordinate: CLLocationCoordinate2D(latitude: 46.4889, longitude: 30.7444),
                candidateShelters: [
                    ShelterItem(id: "od_port", name: "Бункери Одеського морського порту", address: "Митна площа, 1", lat: 46.4889, lon: 30.7444, distance_m: 50.0, type: "bomb_shelter", capacity: 3000, accessible: true, source: "gov", is_primary: true, is_night_accessible: true, is_vehicle_accessible: false)
                ],
                expectedSelectedId: "od_port",
                expectedCategory: .primary,
                shouldShowWarning: false
            ),

            // 5. Poltava Korpusnyi Park (Primary Regional Hospital vs Secondary Ekvator)
            EmulatedScenario(
                cityName: "Полтава (Центр)",
                coordinate: CLLocationCoordinate2D(latitude: 49.5883, longitude: 34.5514),
                candidateShelters: [
                    ShelterItem(id: "pol_hosp", name: "Бомбосховище Полтавської обласної лікарні", address: "вул. Шевченка, 23", lat: 49.5883, lon: 34.5514, distance_m: 400.0, type: "hospital_shelter", capacity: 1100, accessible: true, source: "gov", is_primary: true, is_night_accessible: true, is_vehicle_accessible: false),
                    ShelterItem(id: "pol_ekv", name: "Паркінг ТРЦ «Екватор»", address: "вул. Ковпака, 26", lat: 49.6200, lon: 34.5100, distance_m: 4500.0, type: "mall_parking", capacity: 1200, accessible: true, source: "gov", is_primary: false, is_night_accessible: true, is_vehicle_accessible: true)
                ],
                expectedSelectedId: "pol_hosp",
                expectedCategory: .primary,
                shouldShowWarning: false
            ),

            // 6. Rural Village Uhersko (Extended Cascade -> Stryi Hospital)
            EmulatedScenario(
                cityName: "Село Угерсько (Стрийський район)",
                coordinate: CLLocationCoordinate2D(latitude: 49.2856, longitude: 23.8611),
                candidateShelters: [
                    ShelterItem(id: "stryi_hosp", name: "Стрийська міська лікарня", address: "вул. Багряного, 4", lat: 49.2600, lon: 23.8500, distance_m: 3200.0, type: "hospital_shelter", capacity: 800, accessible: true, source: "gov", is_primary: true, is_night_accessible: true, is_vehicle_accessible: false)
                ],
                expectedSelectedId: "stryi_hosp",
                expectedCategory: .primary,
                shouldShowWarning: false
            )
        ]

        let searchRadius = 1500.0

        for sc in scenarios {
            let inRadius = sc.candidateShelters.filter { $0.distance_m <= searchRadius }
            let primaryInRadius = inRadius.filter { $0.category == .primary }
            let secondaryInRadius = inRadius.filter { $0.category == .secondary }

            if !primaryInRadius.isEmpty {
                let chosen = primaryInRadius.min(by: { $0.distance_m < $1.distance_m })!
                XCTAssertEqual(chosen.id, sc.expectedSelectedId, "Failed scenario for \(sc.cityName)")
                XCTAssertEqual(chosen.category, sc.expectedCategory)
            } else if !secondaryInRadius.isEmpty {
                let chosen = secondaryInRadius.min(by: { $0.distance_m < $1.distance_m })!
                XCTAssertEqual(chosen.id, sc.expectedSelectedId, "Failed scenario for \(sc.cityName)")
                XCTAssertEqual(chosen.category, sc.expectedCategory)
                XCTAssertTrue(sc.shouldShowWarning, "Warning banner should be triggered for secondary fallback in \(sc.cityName)")
            } else {
                // Extended regional fallback
                let regional = sc.candidateShelters.min(by: { $0.distance_m < $1.distance_m })!
                XCTAssertEqual(regional.id, sc.expectedSelectedId, "Failed regional fallback for \(sc.cityName)")
            }
        }
    }

    func testShelterCategoryAndNightAccessProperties() {
        // Category verification
        XCTAssertEqual(ShelterType.metro.category, .primary)
        XCTAssertEqual(ShelterType.bombShelter.category, .primary)
        XCTAssertEqual(ShelterType.bunker.category, .primary)
        XCTAssertEqual(ShelterType.radiationShelter.category, .primary)
        XCTAssertEqual(ShelterType.civilDefense.category, .primary)

        XCTAssertEqual(ShelterType.mallParking.category, .secondary)
        XCTAssertEqual(ShelterType.undergroundParking.category, .secondary)
        XCTAssertEqual(ShelterType.openParking.category, .secondary)
        XCTAssertEqual(ShelterType.schoolShelter.category, .secondary)
        XCTAssertEqual(ShelterType.hospitalShelter.category, .secondary)
        XCTAssertEqual(ShelterType.adminShelter.category, .secondary)

        // Night accessibility
        XCTAssertTrue(ShelterType.metro.isNightAccessible)
        XCTAssertTrue(ShelterType.mallParking.isNightAccessible)
        XCTAssertTrue(ShelterType.undergroundParking.isNightAccessible)
        XCTAssertTrue(ShelterType.bombShelter.isNightAccessible)
        XCTAssertTrue(ShelterType.hospitalShelter.isNightAccessible)
        XCTAssertFalse(ShelterType.schoolShelter.isNightAccessible)
        XCTAssertFalse(ShelterType.adminShelter.isNightAccessible)

        // Vehicle accessibility
        XCTAssertTrue(ShelterType.mallParking.isVehicleAccessible)
        XCTAssertTrue(ShelterType.undergroundParking.isVehicleAccessible)
        XCTAssertTrue(ShelterType.openParking.isVehicleAccessible)
        XCTAssertFalse(ShelterType.metro.isVehicleAccessible)
        XCTAssertFalse(ShelterType.schoolShelter.isVehicleAccessible)

        // Name heuristics for major Ukrainian shopping malls
        let rawNull: String? = nil
        XCTAssertEqual(ShelterType.matching(from: rawNull, name: "Підземний паркінг ТРЦ Retroville"), .mallParking)
        XCTAssertEqual(ShelterType.matching(from: rawNull, name: "Паркінг ТРЦ Lavina Mall"), .mallParking)
        XCTAssertEqual(ShelterType.matching(from: rawNull, name: "ТРЦ Forum Lviv паркінг"), .mallParking)
        XCTAssertEqual(ShelterType.matching(from: rawNull, name: "ТРК МОСТ-Сіті паркінг Дніпро"), .mallParking)
        XCTAssertEqual(ShelterType.matching(from: rawNull, name: "ТЦ Епіцентр Стрий парковка"), .mallParking)
    }

    func testTrackedRegionsToggleAndExclusionLogic() {
        let settings = NotificationSettings.shared
        
        // 1. All regions tracked -> isTracked is true for any region
        settings.allRegionsTracked = true
        settings.trackedRegionsString = RegionRegistry.allRegions.joined(separator: ";")
        XCTAssertTrue(settings.isTracked("Київська область"))
        XCTAssertTrue(settings.isTracked("Львівська область"))

        // 2. Turning off all regions -> trackedRegionsString empty -> isTracked must be false for ALL regions
        settings.allRegionsTracked = false
        settings.trackedRegionsString = ""
        XCTAssertFalse(settings.isTracked("Київська область"), "When allRegionsTracked is false and string is empty, isTracked must be false")
        XCTAssertFalse(settings.isTracked("Львівська область"))
        XCTAssertFalse(settings.isTracked("Одеська область"))

        // 3. Enabling a specific single region
        settings.setTracked("Львівська область", isOn: true)
        XCTAssertTrue(settings.isTracked("Львівська область"))
        XCTAssertFalse(settings.isTracked("Київська область"))
        XCTAssertFalse(settings.allRegionsTracked)

        // 4. Removing the single region
        settings.setTracked("Львівська область", isOn: false)
        XCTAssertFalse(settings.isTracked("Львівська область"))
        XCTAssertFalse(settings.allRegionsTracked)

        // Reset to default
        settings.allRegionsTracked = true
        settings.trackedRegionsString = RegionRegistry.allRegions.joined(separator: ";")
    }

    func testShelterTypeClassificationAndIcons() {
        XCTAssertEqual(ShelterType.matching(from: "metro").iconName, "tram.fill")
        XCTAssertEqual(ShelterType.matching(from: "underground_parking").iconName, "parkingsign.circle.fill")
        XCTAssertEqual(ShelterType.matching(from: "bunker").iconName, "shield.checkered")
        XCTAssertEqual(ShelterType.matching(from: "radiation_shelter").iconName, "radiation")
        XCTAssertEqual(ShelterType.matching(from: "school_shelter").iconName, "graduationcap.fill")
        XCTAssertEqual(ShelterType.matching(from: "hospital_shelter").iconName, "cross.case.fill")
        XCTAssertEqual(ShelterType.matching(from: "admin_shelter").iconName, "building.columns.fill")
        XCTAssertEqual(ShelterType.matching(from: "underground").iconName, "arrow.down.to.line")
        XCTAssertEqual(ShelterType.matching(from: "bomb_shelter").iconName, "shield.fill")

        // Name heuristics fallback
        XCTAssertEqual(ShelterType.iconName(for: "Станція метро Хрещатик"), "tram.fill")
        XCTAssertEqual(ShelterType.iconName(for: "Підземний паркінг ТРЦ"), "parkingsign.circle.fill")
        XCTAssertEqual(ShelterType.iconName(for: "Протирадіаційне сховище"), "radiation")
        XCTAssertEqual(ShelterType.iconName(for: "Військовий бункер"), "shield.checkered")
        XCTAssertEqual(ShelterType.iconName(for: "Угерський ліцей"), "graduationcap.fill")
        XCTAssertEqual(ShelterType.iconName(for: "Стрийська міська лікарня"), "cross.case.fill")
        XCTAssertEqual(ShelterType.iconName(for: "Сільська рада / Старостат"), "building.columns.fill")
        XCTAssertEqual(ShelterType.iconName(for: "Захисна споруда №14"), "shield.fill")
    }

    func testShelterFormatterDistanceAndTravelTime() {
        XCTAssertEqual(ShelterFormatter.formatDistance(meters: 450), "450 м")
        XCTAssertEqual(ShelterFormatter.formatDistance(meters: 999), "999 м")
        XCTAssertEqual(ShelterFormatter.formatDistance(meters: 1000), "1.0 км")
        XCTAssertEqual(ShelterFormatter.formatDistance(meters: 2450), "2.5 км")
        XCTAssertEqual(ShelterFormatter.formatDistance(meters: 15300), "15.3 км")

        XCTAssertEqual(ShelterFormatter.formatTravelTime(seconds: 45), "1 хв")
        XCTAssertEqual(ShelterFormatter.formatTravelTime(seconds: 300), "5 хв")
        XCTAssertEqual(ShelterFormatter.formatTravelTime(seconds: 3600), "1 год")
        XCTAssertEqual(ShelterFormatter.formatTravelTime(seconds: 4500), "1 год 15 хв")
    }

    func testShelterItemDisplayNameAndModel() {
        let itemWithAddress = ShelterItem(
            id: "s1",
            name: "Бомбосховище №5",
            address: "вул. Хрещатик, 1",
            lat: 50.4501,
            lon: 30.5234,
            distance_m: 250,
            type: "bomb_shelter",
            capacity: 500,
            accessible: true,
            source: "gov"
        )
        XCTAssertEqual(itemWithAddress.displayName, "Бомбосховище №5 — вул. Хрещатик, 1")
        XCTAssertEqual(itemWithAddress.distanceText, "250 м")
        XCTAssertEqual(itemWithAddress.iconName, "shield.fill")

        let itemNoName = ShelterItem(
            id: "s2",
            name: nil,
            address: "вул. Шевченка, 10",
            lat: 50.4501,
            lon: 30.5234,
            distance_m: 1400,
            type: "metro",
            capacity: 2000,
            accessible: true,
            source: "osm"
        )
        XCTAssertEqual(itemNoName.displayName, "Станція метро — вул. Шевченка, 10")
        XCTAssertEqual(itemNoName.distanceText, "1.4 км")
        XCTAssertEqual(itemNoName.iconName, "tram.fill")
    }

    func testShelterOptimalCameraRect() {
        let sampleRect = MKMapRect(x: 10000, y: 10000, width: 2000, height: 3000)
        let padded = ShelterRouteService.optimalCameraRect(for: sampleRect)
        XCTAssertTrue(padded.size.width > sampleRect.size.width)
        XCTAssertTrue(padded.size.height > sampleRect.size.height)
        XCTAssertTrue(padded.origin.x < sampleRect.origin.x)
        XCTAssertTrue(padded.origin.y < sampleRect.origin.y)
    }

    func testMultiWaypointTrajectoryAzovDniproMykolaiv() {
        // Target: Mykolaiv (46.9750, 31.9946)
        let mykolaivTarget = CLLocationCoordinate2D(latitude: 46.9750, longitude: 31.9946)
        // Transit: Dnipropetrovsk Oblast centroid (48.4647, 35.0462)
        let dniproTransit = CLLocationCoordinate2D(latitude: 48.4647, longitude: 35.0462)
        // Launch sector: Azov Sea (46.20, 36.50)
        let azovLaunchSector = CLLocationCoordinate2D(latitude: 46.20, longitude: 36.50)
        // Carrier: Morozovsk Airbase (48.31, 41.79)
        let morozovskCarrier = CLLocationCoordinate2D(latitude: 48.31, longitude: 41.79)

        let trajectory = calculateTrajectory(
            target: mykolaivTarget,
            threatType: "shahed",
            customOrigin: dniproTransit,
            carrierOrigin: morozovskCarrier,
            launchSector: azovLaunchSector,
            carrierOriginName: "Аеродром Морозовськ",
            launchSectorName: "Акваторія Азовського моря"
        )

        // 1. Full trajectory starts at Azov Sea and terminates before Mykolaiv with standoff
        XCTAssertFalse(trajectory.fullPoints.isEmpty)
        let firstPt = trajectory.fullPoints.first!
        let lastPt = trajectory.fullPoints.last!
        
        XCTAssertEqual(firstPt.latitude, 46.20, accuracy: 0.01)
        XCTAssertEqual(firstPt.longitude, 36.50, accuracy: 0.01)
        
        // Assert standoff gap between tip and target coordinate (12 - 25 km)
        let dLatTip = (trajectory.tipCoordinate.latitude - mykolaivTarget.latitude) * 111.0
        let dLonTip = (trajectory.tipCoordinate.longitude - mykolaivTarget.longitude) * 111.0 * cos(mykolaivTarget.latitude * .pi / 180.0)
        let standoffDist = sqrt(dLatTip * dLatTip + dLonTip * dLonTip)
        XCTAssertTrue(standoffDist >= 12.0 && standoffDist <= 25.0, "Standoff distance should be 12-25 km, got \(standoffDist) km")
        XCTAssertEqual(lastPt.latitude, trajectory.tipCoordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(lastPt.longitude, trajectory.tipCoordinate.longitude, accuracy: 0.0001)

        // 2. Trajectory midpoint passes near Dnipro transit waypoint
        let midPt = trajectory.fullPoints[trajectory.fullPoints.count / 2]
        let dLatMid = abs(midPt.latitude - dniproTransit.latitude)
        let dLonMid = abs(midPt.longitude - dniproTransit.longitude)
        XCTAssertTrue(dLatMid < 0.5, "Trajectory midpoint should pass near Dnipro latitude")
        XCTAssertTrue(dLonMid < 0.5, "Trajectory midpoint should pass near Dnipro longitude")

        // 3. Flow arrows, checkpoint, and arrowhead tip angle exist
        XCTAssertFalse(trajectory.flowArrows.isEmpty)
        XCTAssertTrue(trajectory.lastCheckpointCoordinate.latitude > 46.0)
        XCTAssertTrue(trajectory.tipAngle != 0.0)

        // 4. Carrier approach connects Morozovsk to Azov Sea launch sector
        XCTAssertNotNil(trajectory.carrierApproachPoints)
        let approachFirst = trajectory.carrierApproachPoints!.first!
        let approachLast = trajectory.carrierApproachPoints!.last!
        XCTAssertEqual(approachFirst.latitude, 48.31, accuracy: 0.01)
        XCTAssertEqual(approachLast.latitude, 46.20, accuracy: 0.01)
    }

    func testTrajectoryStandoffAndArrowheadAngle() {
        let kyivTarget = CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)
        let kurskOrigin = CLLocationCoordinate2D(latitude: 51.70, longitude: 35.50)

        let trajectory = calculateTrajectory(
            target: kyivTarget,
            threatType: "shahed",
            customOrigin: kurskOrigin
        )

        XCTAssertFalse(trajectory.fullPoints.isEmpty)
        let tip = trajectory.tipCoordinate
        let dLat = (tip.latitude - kyivTarget.latitude) * 111.0
        let dLon = (tip.longitude - kyivTarget.longitude) * 111.0 * cos(kyivTarget.latitude * .pi / 180.0)
        let dist = sqrt(dLat * dLat + dLon * dLon)

        XCTAssertTrue(dist >= 12.0 && dist <= 26.0, "Standoff distance should be around 22 km, got \(dist) km")
        // Direction from Kursk to Kyiv is West-Southwest (~240°-270°)
        XCTAssertTrue(trajectory.tipAngle > 180.0 && trajectory.tipAngle < 300.0, "Tip angle should point towards Kyiv, got \(trajectory.tipAngle)")
    }

    func testTrajectoryTaperingProgression() {
        let dniproTarget = CLLocationCoordinate2D(latitude: 48.4647, longitude: 35.0462)
        let azovOrigin = CLLocationCoordinate2D(latitude: 46.20, longitude: 36.50)

        let trajectory = calculateTrajectory(
            target: dniproTarget,
            threatType: "shahed",
            customOrigin: azovOrigin
        )

        XCTAssertFalse(trajectory.taperedSegments.isEmpty, "Trajectory should have tapered segments")
        XCTAssertEqual(trajectory.taperedSegments.count, 3, "Trajectory should produce 3 aerodynamic tapered segments")

        let firstSegment = trajectory.taperedSegments.first!
        let lastSegment = trajectory.taperedSegments.last!

        // Assert that origin segment is wider than target tip segment
        XCTAssertGreaterThan(firstSegment.beamWidth, lastSegment.beamWidth, "Launch segment must be wider than tip segment")
        XCTAssertGreaterThan(firstSegment.glowWidth, lastSegment.glowWidth, "Launch glow must be wider than tip glow")
        XCTAssertGreaterThan(firstSegment.coreWidth, lastSegment.coreWidth, "Launch core must be wider than tip core")

        // Assert strictly decreasing beam width progression
        for i in 0..<(trajectory.taperedSegments.count - 1) {
            let current = trajectory.taperedSegments[i]
            let next = trajectory.taperedSegments[i + 1]
            XCTAssertGreaterThanOrEqual(current.beamWidth, next.beamWidth, "Beam width must smoothly decrease or remain monotonic")
        }
    }
}

