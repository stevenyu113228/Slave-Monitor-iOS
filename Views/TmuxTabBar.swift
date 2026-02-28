import SwiftUI

struct TmuxTabBar: View {
    @Environment(AppState.self) private var appState
    @State private var windows: [TmuxWindow] = []
    @State private var timer: Timer?
    @State private var renameTarget: TmuxWindow?
    @State private var renameText = ""
    @State private var showRenameAlert = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(windows) { window in
                    tabButton(for: window)
                }

                // New window button
                Button {
                    Task {
                        try? await appState.apiClient.newWindow()
                        await refreshWindows()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(white: 0.2))
                        )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(Color(red: 0.12, green: 0.12, blue: 0.12))
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
        .alert("Rename Window", isPresented: $showRenameAlert) {
            TextField("Window name", text: $renameText)
            Button("Rename") {
                guard let target = renameTarget else { return }
                Task { await renameWindow(target, to: renameText) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func tabButton(for window: TmuxWindow) -> some View {
        Button {
            Task {
                try? await appState.apiClient.selectWindow(index: window.index)
                await refreshWindows()
            }
        } label: {
            HStack(spacing: 4) {
                if window.active {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                }
                Text("\(window.index):\(window.name)")
                    .font(.system(size: 13, weight: window.active ? .semibold : .regular, design: .monospaced))
                    .foregroundStyle(window.active ? .white : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(window.active
                          ? Color(white: 0.25)
                          : Color(white: 0.15))
            )
        }
        .contextMenu {
            Button("Rename...") {
                renameTarget = window
                renameText = window.name
                showRenameAlert = true
            }
            Button("Close Window", role: .destructive) {
                Task {
                    try? await appState.apiClient.closeWindow(index: window.index)
                    await refreshWindows()
                }
            }
        }
    }

    private func startPolling() {
        Task { await refreshWindows() }
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { await refreshWindows() }
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    private func refreshWindows() async {
        do {
            windows = try await appState.apiClient.listWindows()
        } catch {
            // Silently ignore — will retry on next poll
        }
    }

    private func renameWindow(_ window: TmuxWindow, to name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Send rename command via exec endpoint
        try? await appState.apiClient.execCommand(
            "tmux rename-window -t \(appState.tmuxSession):\(window.index) '\(trimmed)'"
        )
        await refreshWindows()
    }
}
