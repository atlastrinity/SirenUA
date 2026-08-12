import CoreLocation
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

    func testAlertRegionEqualityUsesIDOnly() {
        let first = AlertRegion(
            id: 1,
            name: "Київська область",
            isActive: true,
            level: 3,
            description: "Повітряна тривога!",
            coordinate: CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)
        )
        let second = AlertRegion(
            id: 1,
            name: "Львівська область",
            isActive: false,
            level: 0,
            description: "Немає тривоги",
            coordinate: CLLocationCoordinate2D(latitude: 49.8397, longitude: 24.0297)
        )

        XCTAssertEqual(first, second)
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
        let tenMinAgo = Date().addingTimeInterval(-600)
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
        XCTAssertEqual(threat.dynamicETA, "~15  хв".replacingOccurrences(of: "  ", with: " ")) // Expected remaining 15 mins (with double space normalization or direct match)
    }

    func testDynamicDistanceCalculations() throws {
        // Formulate an ISO string 15 minutes ago
        let fifteenMinAgo = Date().addingTimeInterval(-900)
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

        // 6. vibrationEnabled toggle
        defaults.set(false, forKey: "vibrationEnabled")
        XCTAssertFalse(defaults.bool(forKey: "vibrationEnabled"))

        defaults.set(true, forKey: "vibrationEnabled")
        XCTAssertTrue(defaults.bool(forKey: "vibrationEnabled"))
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
}
