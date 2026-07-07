import Foundation
import Combine
import OSLog

private let wsLogger = Logger(subsystem: "com.sirenua", category: "WebSocket")

enum WebSocketEvent: Sendable {
    case initialState([String: ThreatInfo])
    case threatUpdate(region: String, threat: ThreatInfo)
}

final class ThreatWebSocketClient: ObservableObject, @unchecked Sendable {
    static let shared = ThreatWebSocketClient()

    @Published var connectionState: ConnectionState = .disconnected
    let events = PassthroughSubject<WebSocketEvent, Never>()

    enum ConnectionState {
        case disconnected, connecting, connected
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var serverURLString: String?
    
    private var isIntentionalDisconnect = false
    private var retryCount = 0
    private let maxRetries = 5

    private init() {}

    func connect(to urlString: String) {
        let wsURLString = urlString.replacingOccurrences(of: "http", with: "ws")
        let fullURLString = wsURLString.hasSuffix("/") ? "\(wsURLString)ws" : "\(wsURLString)/ws"
        
        guard let url = URL(string: fullURLString) else {
            wsLogger.error("Invalid WebSocket URL")
            return
        }
        self.serverURLString = urlString
        self.isIntentionalDisconnect = false
        
        wsLogger.info("Connecting to WebSocket: \(url.absoluteString)")
        DispatchQueue.main.async {
            self.connectionState = .connecting
        }
        
        let request = URLRequest(url: url)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        DispatchQueue.main.async {
            self.connectionState = .connected
        }
        retryCount = 0
        receiveMessage()
        startPingTimer()
    }

    func disconnect() {
        isIntentionalDisconnect = true
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue listening
                self.receiveMessage()
                
            case .failure(let error):
                wsLogger.error("WebSocket receiving error: \(error.localizedDescription)")
                self.handleDisconnection()
            }
        }
    }

    private func handleMessage(_ jsonString: String) {
        if jsonString == "pong" { return }
        guard let data = jsonString.data(using: .utf8) else { return }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            guard let type = json?["type"] as? String else { return }
            
            if type == "initial_state" {
                if let threatsDict = json?["threats"] as? [String: Any] {
                    let decoder = JSONDecoder()
                    let threatData = try JSONSerialization.data(withJSONObject: threatsDict, options: [])
                    let decodedThreats = try decoder.decode([String: ThreatInfo].self, from: threatData)
                    
                    DispatchQueue.main.async {
                        self.events.send(.initialState(decodedThreats))
                    }
                }
            } else if type == "threat_update" {
                if let region = json?["region"] as? String,
                   let stateDict = json?["state"] as? [String: Any] {
                    
                    let level = stateDict["level"] as? String ?? "none"
                    let threatType = stateDict["type"] as? String
                    let detail = stateDict["detail"] as? String
                    let since = stateDict["since"] as? String
                    let confidence = stateDict["confidence"] as? Int
                    let eta = stateDict["eta"] as? String
                    let isPredictive = stateDict["is_predictive"] as? Bool
                    
                    let threat = ThreatInfo(level: level, type: threatType, detail: detail, since: since,
                                            confidence: confidence, eta: eta, is_predictive: isPredictive)
                    
                    DispatchQueue.main.async {
                        self.events.send(.threatUpdate(region: region, threat: threat))
                    }
                }
            }
        } catch {
            wsLogger.error("Error decoding WebSocket message: \(error.localizedDescription)")
        }
    }

    private func handleDisconnection() {
        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
        
        guard !isIntentionalDisconnect else { return }
        
        // Reconnect logic
        if retryCount < maxRetries {
            retryCount += 1
            let delay = pow(2.0, Double(retryCount))
            wsLogger.info("Reconnecting in \(delay) seconds...")
            
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                if let serverURL = self?.serverURLString {
                    self?.connect(to: serverURL)
                }
            }
        }
    }
    
    private func startPingTimer() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self else { return }
            if self.connectionState == .connected {
                self.webSocketTask?.send(.string("ping")) { error in
                    if let error = error {
                        wsLogger.error("Ping failed: \(error.localizedDescription)")
                    } else {
                        self.startPingTimer()
                    }
                }
            }
        }
    }
}
