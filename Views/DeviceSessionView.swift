import SwiftUI

struct DeviceSessionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    let profile: DeviceProfile
    let connection: DeviceConnection

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Connection status bar
                connectionBar

                // tmux tab bar
                if connection.connectionStatus == .connected {
                    TmuxTabBar(apiClient: connection.apiClient, tmuxSession: profile.tmuxSession)
                }

                // Terminal
                TerminalContainerView(bridge: connection.bridge)
                    .ignoresSafeArea(.keyboard)

                // Quick keys
                if connection.connectionStatus == .connected {
                    QuickKeysView(client: connection.ttydClient)
                }

                // Input bar
                InputBarView(client: connection.ttydClient, apiClient: connection.apiClient)
            }

            // Kicked overlay
            if connection.connectionStatus == .kicked {
                kickedOverlay
            }
        }
        .onAppear { connectIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if connection.connectionStatus == .kicked {
                    return  // Don't auto-reconnect when kicked
                }
                if connection.connectionStatus == .disconnected {
                    connection.connect()
                }
            case .background:
                if connection.connectionStatus != .kicked {
                    connection.disconnect()
                }
            default:
                break
            }
        }
    }

    private var connectionBar: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(profile.tailscaleIP)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
    }

    private var statusColor: Color {
        switch connection.connectionStatus {
        case .connected: .green
        case .connecting: .orange
        case .disconnected: .red
        case .kicked: .purple
        }
    }

    private var statusText: String {
        switch connection.connectionStatus {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .kicked:
            if let device = connection.kickedByDevice {
                "Taken over by \(device)"
            } else {
                "Session taken over"
            }
        }
    }

    // MARK: - Kicked Overlay

    private var kickedOverlay: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)

                Text("Session Taken Over")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                if let device = connection.kickedByDevice {
                    Text("Connected from: \(device)")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }

                Button(action: { connection.reclaim() }) {
                    Text("Reconnect")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
        }
    }

    private func connectIfNeeded() {
        if connection.connectionStatus == .disconnected {
            connection.connect()
        }
    }
}
