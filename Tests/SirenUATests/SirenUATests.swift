import XCTest
@testable import SirenUA

class MockURLProtocol: URLProtocol {
    static var mockData: Data?
    static var mockResponse: URLResponse?
    static var mockError: Error?

    override class func canInit(with request: URLRequest) -> Bool { return true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { return request }
    override func startLoading() {
        if let error = MockURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            if let response = MockURLProtocol.mockResponse {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data = MockURLProtocol.mockData {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

final class SirenUATests: XCTestCase {
    func testAlertParsing() async throws {
        let json = """
        {
            "last_update": "2023-01-01T00:00:00Z",
            "states": [
                {
                    "id": 1,
                    "name": "Kyiv",
                    "state": "alert",
                    "description": "Air Raid"
                },
                {
                    "id": 2,
                    "name": "Lviv",
                    "state": "partial",
                    "description": "Partial Alert"
                }
            ]
        }
        """
        MockURLProtocol.mockData = json.data(using: .utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(url: URL(string: "https://alerts.in.ua/api/air-raid")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let manager = NetworkManager(session: session)
        do {
            let alerts = try await manager.fetchAlerts()
            XCTAssertEqual(alerts.count, 2, "Should have 2 alerts")
            XCTAssertEqual(alerts[0].name, "Kyiv")
            XCTAssertEqual(alerts[0].isActive, true)
            XCTAssertEqual(alerts[1].name, "Lviv")
            XCTAssertEqual(alerts[1].isActive, false)
        } catch {
            print("TEST FAILED WITH ERROR: \(error)")
            throw error
        }
    }
}
