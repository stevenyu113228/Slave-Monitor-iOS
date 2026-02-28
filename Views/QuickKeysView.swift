import SwiftUI

struct QuickKeysView: View {
    let client: TtydClient
    @Environment(AppState.self) private var appState
    @State private var showCopyOverlay = false
    @State private var copyText = ""
    @State private var isScrollMode = false
    @State private var scrollTimer: Timer?

    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: terminal keys
            HStack(spacing: 4) {
                keyButton("▲", bytes: [0x1B, 0x5B, 0x41])
                keyButton("▼", bytes: [0x1B, 0x5B, 0x42])
                keyButton("Tab", bytes: [0x09])
                keyButton("Esc", bytes: [0x1B])
                keyButton("Ctrl+C", bytes: [0x03])
                keyButton("Enter", bytes: [0x0D])
                keyButton("Clear", bytes: [0x0C])
            }
            .padding(.horizontal, 6)
            .padding(.top, 5)
            .padding(.bottom, 3)

            // Row 2: actions
            HStack(spacing: 4) {
                keyButton("Ctrl+O", bytes: [0x0F])
                keyButton("Ctrl+U", bytes: [0x15])
                actionButton("New") { performNew() }
                actionButton("Resume") { performResume() }
                actionButton("Copy") { performCopy() }
                actionButton("Scroll") { performScroll() }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 5)
        }
        .background(Color(red: 0.13, green: 0.13, blue: 0.13))
        .fullScreenCover(isPresented: $showCopyOverlay) {
            CopyOverlayView(
                text: $copyText,
                isScrollMode: $isScrollMode,
                onClose: closeCopyOverlay,
                onRefresh: refreshCopyText
            )
        }
    }

    // MARK: - Button Builders

    @ViewBuilder
    private func keyButton(_ label: String, bytes: [UInt8]) -> some View {
        Button {
            haptic.impactOccurred()
            client.sendInput(bytes)
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(QKButtonStyle())
    }

    @ViewBuilder
    private func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            haptic.impactOccurred()
            action()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(QKButtonStyle())
    }

    // MARK: - Actions

    private func performNew() {
        let exitBytes = Array("/exit".utf8) + [0x0D]
        client.sendInput(exitBytes)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let bytes = Array("claude".utf8) + [0x0D]
            client.sendInput(bytes)
        }
    }

    private func performResume() {
        let exitBytes = Array("/exit".utf8) + [0x0D]
        client.sendInput(exitBytes)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let bytes = Array("claude --resume".utf8) + [0x0D]
            client.sendInput(bytes)
        }
    }

    private func performCopy() {
        isScrollMode = false
        Task {
            copyText = await capturePane()
            showCopyOverlay = true
        }
    }

    private func performScroll() {
        isScrollMode = true
        Task {
            copyText = await capturePane()
            showCopyOverlay = true
        }
    }

    private func closeCopyOverlay() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        showCopyOverlay = false
        copyText = ""
    }

    private func refreshCopyText() {
        Task {
            copyText = await capturePane()
        }
    }

    private func capturePane() async -> String {
        do {
            return try await appState.apiClient.capturePane(session: appState.tmuxSession)
        } catch {
            return "(Failed to capture pane)"
        }
    }
}

// MARK: - Button Style

private struct QKButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(0.9))
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed
                          ? Color(white: 0.35)
                          : Color(white: 0.2))
            )
    }
}

// MARK: - Copy/Scroll Overlay

struct CopyOverlayView: View {
    @Binding var text: String
    @Binding var isScrollMode: Bool
    let onClose: () -> Void
    let onRefresh: () -> Void
    @State private var scrollTimer: Timer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(isScrollMode ? "Scroll View" : "Copy Text")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if isScrollMode {
                        Text("Auto-refresh: 3s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Close") { onClose() }
                        .foregroundStyle(.blue)
                }
                .padding()

                // Hint
                Text("Long-press to select, then Copy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                // Content
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(text)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .textSelection(.enabled)
                            .id("content")
                    }
                    .background(Color(red: 0.08, green: 0.08, blue: 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                    .onChange(of: text) {
                        if isScrollMode {
                            withAnimation {
                                proxy.scrollTo("content", anchor: .bottom)
                            }
                        }
                    }
                }

                // Scroll nav buttons (scroll mode only)
                if isScrollMode {
                    HStack(spacing: 8) {
                        Button {
                            onRefresh()
                        } label: {
                            Text("Refresh Now")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.25)))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .onAppear {
            if isScrollMode {
                scrollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                    onRefresh()
                }
            }
        }
        .onDisappear {
            scrollTimer?.invalidate()
            scrollTimer = nil
        }
    }
}
