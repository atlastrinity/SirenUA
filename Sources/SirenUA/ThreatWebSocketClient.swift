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

    private init() {}

    func connect(to urlString: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Prevent redundant connections if already connected or connecting to the same URL
            if (self.connectionState == .connected || self.connectionState == .connecting) && self.serverURLString == urlString {
                wsLogger.info("Already connected or connecting to \(urlString), skipping connection request.")
                return
            }

            // Cancel existing task to prevent duplicates or resource leaks
            self.webSocketTask?.cancel(with: .goingAway, reason: nil)
            
            let wsURLString = urlString.replacingOccurrences(of: "http", with: "ws")
            let fullURLString = wsURLString.hasSuffix("/") ? "\(wsURLString)ws" : "\(wsURLString)/ws"
            
            guard let url = URL(string: fullURLString) else {
                wsLogger.error("Invalid WebSocket URL")
                return
            }
            self.serverURLString = urlString
            self.isIntentionalDisconnect = false
            
            wsLogger.info("Connecting to WebSocket: \(url.absoluteString)")
            self.connectionState = .connecting
            
            let request = URLRequest(url: url)
            let task = self.session.webSocketTask(with: request)
            self.webSocketTask = task
            task.resume()
            
            // Reset retry count on manual connection request
            self.retryCount = 0
            
            self.receiveMessage()
            self.startPingTimer(for: task)
        }
    }

    func disconnect() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isIntentionalDisconnect = true
            self.webSocketTask?.cancel(with: .goingAway, reason: nil)
            self.webSocketTask = nil
            self.connectionState = .disconnected
        }
    }

    func reconnect() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let url = self.serverURLString else { return }
            self.retryCount = 0
            self.connect(to: url)
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        wsLogger.info("WebSocket: received message string: \(String(text.prefix(150)))...")
                        self.handleMessage(text)
                    case .data(let data):
                        wsLogger.info("WebSocket: received message data (bytes: \(data.count))")
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
    }

    private func handleMessage(_ jsonString: String) {
        if jsonString == "pong" { return }
        guard let data = jsonString.data(using: .utf8) else { return }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            guard let type = json?["type"] as? String else {
                wsLogger.warning("WebSocket: missing message 'type' field")
                return
            }
            
            wsLogger.info("WebSocket: processing event type: \(type)")
            
            if type == "initial_state" {
                if let threatsDict = json?["threats"] as? [String: Any] {
                    let decoder = JSONDecoder()
                    let threatData = try JSONSerialization.data(withJSONObject: threatsDict, options: [])
                    let decodedThreats = try decoder.decode([String: ThreatInfo].self, from: threatData)
                    
                    self.connectionState = .connected
                    self.retryCount = 0 // Reset retries on successful connection
                    wsLogger.info("WebSocket: successfully decoded initial state for \(decodedThreats.count) regions")
                    self.events.send(.initialState(decodedThreats))
                } else {
                    wsLogger.warning("WebSocket: 'initial_state' missing 'threats' field")
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
                    let isActive = stateDict["is_active"] as? Bool
                    
                    let threat = ThreatInfo(level: level, type: threatType, detail: detail, since: since,
                                            confidence: confidence, eta: eta, is_predictive: isPredictive, is_active: isActive)
                    
                    // Fallback connection state updates if initial_state was somehow missed
                    if self.connectionState != .connected {
                        self.connectionState = .connected
                        self.retryCount = 0
                    }
                    wsLogger.info("WebSocket: successfully parsed threat update for \(region), level: \(level), predictive: \(isPredictive ?? false)")
                    self.events.send(.threatUpdate(region: region, threat: threat))
                } else {
                    wsLogger.warning("WebSocket: 'threat_update' missing 'region' or 'state' field")
                }
            } else {
                wsLogger.warning("WebSocket: unhandled event type: \(type)")
            }
        } catch {
            wsLogger.error("Error decoding WebSocket message: \(error.localizedDescription)")
        }
    }

    private func handleDisconnection() {
        self.connectionState = .disconnected
        
        guard !isIntentionalDisconnect else { return }
        
        retryCount += 1
        // Exponential backoff capped at 30 seconds (allows infinite reconnection)
        let delay = min(30.0, pow(2.0, Double(retryCount)))
        wsLogger.info("Reconnecting (attempt \(self.retryCount)) in \(delay) seconds...")
        
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, !self.isIntentionalDisconnect else { return }
                if let serverURL = self.serverURLString {
                    self.connect(to: serverURL)
                }
            }
        }
    }
    
    private func startPingTimer(for task: URLSessionWebSocketTask) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Verify that the task hasn't changed (reconnected) and we are still connected
                guard self.webSocketTask === task, self.connectionState == .connected else { return }
                
                task.send(.string("ping")) { [weak self] error in
                    DispatchQueue.main.async {
                        guard let self = self, self.webSocketTask === task else { return }
                        if let error = error {
                            wsLogger.error("Ping failed: \(error.localizedDescription)")
                            self.handleDisconnection()
                        } else {
                            self.startPingTimer(for: task)
                        }
                    }
                }
            }
        }
    }
}
