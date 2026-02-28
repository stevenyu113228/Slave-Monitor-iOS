import Foundation
import UIKit

@Observable
class DeviceConnection {
    let profile: DeviceProfile
    var connectionStatus: ConnectionStatus = .disconnected
    var kickedByDevice: String?
    let ttydClient = TtydClient()
    let apiClient = APIClient()
    let bridge: TerminalBridge

    private var sessionId: String?
    private var sessionCheckTimer: Timer?

    init(profile: DeviceProfile) {
        self.profile = profile
        self.bridge = TerminalBridge(client: ttydClient)
        self.apiClient.baseURL = profile.apiBaseURL
        self.ttydClient.onDisconnect = { [weak self] in
            guard let self else { return }
            // Don't overwrite .kicked status
            if self.connectionStatus != .kicked {
                self.connectionStatus = .disconnected
            }
        }
    }

    func connect() {
        guard !profile.tailscaleIP.isEmpty else { return }
        connectionStatus = .connecting
        kickedByDevice = nil

        Task {
            // 1. Claim session (fail silently for backward compatibility)
            do {
                sessionId = try await apiClient.claimSession(deviceName: UIDevice.current.name)
            } catch {
                sessionId = nil
            }

            // 2. Connect to ttyd
            do {
                try await ttydClient.connect(
                    host: profile.tailscaleIP,
                    port: profile.ttydPort
                )
                await MainActor.run {
                    self.connectionStatus = .connected
                    // 3. Start session polling if we got a session
                    if self.sessionId != nil {
                        self.startSessionCheck()
                    }
                }
            } catch {
                await MainActor.run { self.connectionStatus = .disconnected }
            }
        }
    }

    func disconnect() {
        stopSessionCheck()
        sessionId = nil
        ttydClient.disconnect()
        if connectionStatus != .kicked {
            connectionStatus = .disconnected
        }
    }

    // MARK: - Reclaim (after being kicked)

    func reclaim() {
        kickedByDevice = nil
        connectionStatus = .disconnected
        connect()
    }

    // MARK: - Session polling

    private func startSessionCheck() {
        stopSessionCheck()
        sessionCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.performSessionCheck()
        }
    }

    private func stopSessionCheck() {
        sessionCheckTimer?.invalidate()
        sessionCheckTimer = nil
    }

    private func performSessionCheck() {
        guard let sid = sessionId else { return }
        Task {
            do {
                let result = try await apiClient.checkSession(sessionId: sid)
                if !result.active {
                    await MainActor.run { self.handleKicked(by: result.current_device) }
                }
            } catch {
                // Network error — don't kick, just skip this check
            }
        }
    }

    private func handleKicked(by device: String?) {
        stopSessionCheck()
        sessionId = nil
        kickedByDevice = device
        connectionStatus = .kicked
        // Disconnect ttyd without triggering auto-reconnect (status already .kicked)
        ttydClient.disconnect()
    }
}
