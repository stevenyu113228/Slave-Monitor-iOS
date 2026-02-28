import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var bridge: TerminalBridge?
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Connection status bar
            connectionBar

            // tmux tab bar
            if appState.connectionStatus == .connected {
                TmuxTabBar()
            }

            // Terminal
            if let bridge {
                TerminalContainerView(bridge: bridge)
                    .ignoresSafeArea(.keyboard)
            } else {
                Spacer()
                Text("Configure Tailscale IP in Settings")
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Quick keys
            if appState.connectionStatus == .connected {
                QuickKeysView(client: appState.client)
            }

            // Input bar
            InputBarView(client: appState.client)
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .onAppear { setupAndConnect() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if appState.connectionStatus == .disconnected {
                    connect()
                }
            case .background:
                appState.client.disconnect()
                appState.connectionStatus = .disconnected
            default:
                break
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var connectionBar: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(appState.connectionStatus.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if !appState.tailscaleIP.isEmpty {
                Text(appState.tailscaleIP)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
    }

    private var statusColor: Color {
        switch appState.connectionStatus {
        case .connected: .green
        case .connecting: .orange
        case .disconnected: .red
        }
    }

    private func setupAndConnect() {
        if bridge == nil {
            bridge = TerminalBridge(client: appState.client)
        }
        appState.apiClient.baseURL = appState.apiBaseURL
        appState.client.onDisconnect = {
            appState.connectionStatus = .disconnected
        }
        connect()
    }

    private func connect() {
        guard !appState.tailscaleIP.isEmpty else { return }
        appState.connectionStatus = .connecting
        Task {
            do {
                try await appState.client.connect(
                    host: appState.tailscaleIP,
                    port: appState.ttydPort
                )
                appState.connectionStatus = .connected
            } catch {
                appState.connectionStatus = .disconnected
            }
        }
    }

}
