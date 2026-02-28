import Foundation
import Combine

struct TokenResponse: Decodable {
    let token: String
}

class TtydClient: ObservableObject {
    @Published var isConnected = false
    @Published var windowTitle: String = ""

    var onOutput: ((Data) -> Void)?
    var onDisconnect: (() -> Void)?

    private var webSocket: URLSessionWebSocketTask?
    private var host: String = ""
    private var port: Int = 7681
    private var retryCount = 0
    private var shouldReconnect = true
    private var pendingResize: (cols: Int, rows: Int)?
    private var pingTimer: Timer?

    func connect(host: String, port: Int = 7681, cols: Int = 80, rows: Int = 24) async throws {
        self.host = host
        self.port = port
        self.shouldReconnect = true
        self.retryCount = 0

        // Clean up any existing connection
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        stopPing()

        await MainActor.run { self.isConnected = false }

        // 1. Fetch token
        let tokenURL = URL(string: "http://\(host):\(port)/token")!
        let (data, _) = try await URLSession.shared.data(from: tokenURL)
        let tokenResp = try JSONDecoder().decode(TokenResponse.self, from: data)

        // 2. Open WebSocket with 'tty' subprotocol (required by ttyd)
        let wsURL = URL(string: "ws://\(host):\(port)/ws")!
        var request = URLRequest(url: wsURL)
        request.setValue("tty", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()

        // 3. Send handshake as text frame (JSON_DATA)
        let currentCols = pendingResize?.cols ?? cols
        let currentRows = pendingResize?.rows ?? rows
        let handshake = "{\"AuthToken\":\"\(tokenResp.token)\",\"columns\":\(currentCols),\"rows\":\(currentRows)}"
        try await webSocket?.send(.string(handshake))

        await MainActor.run { self.isConnected = true }
        NSLog("[TtydClient] Connected OK")
        pendingResize = nil
        receiveLoop()
        startPing()
    }

    func sendInput(_ bytes: [UInt8]) {
        guard isConnected, let ws = webSocket else { return }
        var frame = Data([0x30]) // '0' = INPUT
        frame.append(contentsOf: bytes)
        ws.send(.data(frame)) { [weak self] error in
            if let error {
                print("[TtydClient] sendInput error: \(error)")
                self?.handleDisconnect()
            }
        }
    }

    func sendInputData(_ data: Data) {
        guard isConnected, let ws = webSocket else { return }
        var frame = Data([0x30]) // '0' = INPUT
        frame.append(data)
        ws.send(.data(frame)) { [weak self] error in
            if let error {
                print("[TtydClient] sendInputData error: \(error)")
                self?.handleDisconnect()
            }
        }
    }

    func sendResize(cols: Int, rows: Int) {
        pendingResize = (cols, rows)
        guard isConnected, let ws = webSocket else { return }
        let json = "{\"columns\":\(cols),\"rows\":\(rows)}"
        var frame = Data([0x31]) // '1' = RESIZE
        frame.append(Data(json.utf8))
        ws.send(.data(frame)) { error in
            if let error {
                print("[TtydClient] sendResize error: \(error)")
            }
        }
    }

    func disconnect() {
        shouldReconnect = false
        stopPing()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        Task { @MainActor in
            isConnected = false
        }
    }

    // MARK: - Receive

    private func receiveLoop() {
        guard let ws = webSocket else { return }
        ws.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                if self.isConnected { self.receiveLoop() }

            case .failure(let error):
                print("[TtydClient] receive error: \(error)")
                self.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .data(let d):
            data = d
        case .string(let s):
            data = Data(s.utf8)
        @unknown default:
            return
        }

        guard data.count > 1 else { return }
        let type = data[0]
        let payload = data.subdata(in: 1..<data.count)

        switch type {
        case 0x30: // '0' = OUTPUT
            DispatchQueue.main.async { self.onOutput?(payload) }
        case 0x31: // '1' = TITLE
            if let title = String(data: payload, encoding: .utf8) {
                DispatchQueue.main.async { self.windowTitle = title }
            }
        case 0x32: // '2' = PREFS (ignored)
            break
        default:
            break
        }
    }

    // MARK: - Keep-alive

    private func startPing() {
        DispatchQueue.main.async {
            self.pingTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
                self?.webSocket?.sendPing { error in
                    if let error {
                        print("[TtydClient] ping failed: \(error)")
                        self?.handleDisconnect()
                    }
                }
            }
        }
    }

    private func stopPing() {
        DispatchQueue.main.async {
            self.pingTimer?.invalidate()
            self.pingTimer = nil
        }
    }

    // MARK: - Reconnect

    private func handleDisconnect() {
        DispatchQueue.main.async {
            guard self.isConnected else { return }
            self.isConnected = false
            self.stopPing()
            self.onDisconnect?()
        }
        attemptReconnect()
    }

    private func attemptReconnect() {
        guard shouldReconnect else { return }
        let delay = min(pow(2.0, Double(retryCount)), 30.0)
        retryCount += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.shouldReconnect else { return }
            Task {
                try? await self.connect(host: self.host, port: self.port)
            }
        }
    }
}
