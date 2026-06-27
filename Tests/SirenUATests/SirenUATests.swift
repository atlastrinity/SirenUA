import XCTest
@testable import SirenUA

final class MockURLProtocol: URLProtocol {
    static var mockData: Data?
    static var mockResponse: URLResponse?
    static var mockError: Error?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
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

        XCTAssertEqual(alerts["Київська область"], true)
        XCTAssertEqual(alerts["Львівська область"], false)
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
            XCTAssertEqual(error.localizedDescription, NetworkError.invalidResponse.localizedDescription)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
