import XCTest
@testable import SirenUA

final class SirenUATests: XCTestCase {
    func testAlertParsing() async throws {
        let manager = NetworkManager()
        let alerts = try await manager.fetchAlerts()

        XCTAssertEqual(alerts.count, 2, "Should have 2 alerts")
        XCTAssertEqual(alerts[0].region, "Kyiv")
        XCTAssertEqual(alerts[0].type, "air_raid")
        XCTAssertTrue(alerts[0].active)
        XCTAssertEqual(alerts[1].region, "Lviv")
        XCTAssertFalse(alerts[1].active)
    }
}
