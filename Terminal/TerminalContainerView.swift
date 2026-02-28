import SwiftUI
import SwiftTerm

// Subclass to prevent SwiftTerm from dynamically adding its own pan gesture
// when tmux negotiates mouse mode. mouseModeChanged() is called by Terminal
// when it receives escape sequences like \x1b[?1002h, and the default
// implementation adds a panMouseGesture that conflicts with our scroll handler.
class ClaudeTerminalView: TerminalView {
    override func mouseModeChanged(source: Terminal) {
        // No-op: we handle scroll ourselves via raw SGR escape sequences
    }
}

struct TerminalContainerView: UIViewRepresentable {
    @Environment(AppState.self) private var appState
    let bridge: TerminalBridge

    func makeUIView(context: Context) -> ClaudeTerminalView {
        let terminal = ClaudeTerminalView(frame: .zero)

        // Configure appearance
        let fontSize = appState.fontSize
        terminal.font = UIFont(name: "Menlo", size: fontSize) ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        terminal.nativeBackgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        terminal.nativeForegroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)

        // Scrollback buffer
        terminal.getTerminal().options.scrollback = 10000

        // Disable SwiftTerm's native UIScrollView scrolling and mouse reporting
        terminal.isScrollEnabled = false
        terminal.allowMouseReporting = false
        terminal.panGestureRecognizer.isEnabled = false

        // Hide the default SwiftTerm accessory bar (we have our own QuickKeys)
        terminal.inputAccessoryView = nil

        // Replace gesture recognizers
        replaceGestures(on: terminal, coordinator: context.coordinator)

        // Connect bridge
        terminal.terminalDelegate = bridge
        bridge.terminalView = terminal

        return terminal
    }

    func updateUIView(_ terminal: ClaudeTerminalView, context: Context) {
        let fontSize = appState.fontSize
        let newFont = UIFont(name: "Menlo", size: fontSize) ?? UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if terminal.font.pointSize != newFont.pointSize {
            terminal.font = newFont
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    private func replaceGestures(on terminal: ClaudeTerminalView, coordinator: Coordinator) {
        // Remove ALL gesture recognizers (taps, long press, any SwiftTerm gestures)
        if let gestures = terminal.gestureRecognizers {
            for gesture in gestures {
                // Keep UIScrollView's built-in pan (just disabled)
                if gesture === terminal.panGestureRecognizer { continue }
                terminal.removeGestureRecognizer(gesture)
            }
        }

        // Single-tap: just becomeFirstResponder
        let singleTap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        terminal.addGestureRecognizer(singleTap)

        // Pan: send mouse scroll events to tmux via raw SGR escape sequences
        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        terminal.addGestureRecognizer(pan)
    }

    class Coordinator {
        let bridge: TerminalBridge
        private var accumulatedY: CGFloat = 0
        private var accumulatedX: CGFloat = 0
        private let scrollThreshold: CGFloat = 20
        private let cursorThreshold: CGFloat = 16

        init(bridge: TerminalBridge) {
            self.bridge = bridge
        }

        @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            guard let terminal = gesture.view as? TerminalView else { return }
            if terminal.isFirstResponder {
                terminal.resignFirstResponder()
            } else {
                terminal.becomeFirstResponder()
            }
            UIMenuController.shared.hideMenu()
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                accumulatedY = 0
                accumulatedX = 0
            case .changed:
                let translation = gesture.translation(in: gesture.view)
                accumulatedY += translation.y
                accumulatedX += translation.x
                gesture.setTranslation(.zero, in: gesture.view)

                // Vertical: scroll up/down (SGR mouse wheel)
                while accumulatedY > scrollThreshold {
                    accumulatedY -= scrollThreshold
                    // SGR scroll up: \x1b[<64;1;1M
                    let seq: [UInt8] = [0x1b, 0x5b, 0x3c, 0x36, 0x34, 0x3b, 0x31, 0x3b, 0x31, 0x4d]
                    bridge.client.sendInput(seq)
                }
                while accumulatedY < -scrollThreshold {
                    accumulatedY += scrollThreshold
                    // SGR scroll down: \x1b[<65;1;1M
                    let seq: [UInt8] = [0x1b, 0x5b, 0x3c, 0x36, 0x35, 0x3b, 0x31, 0x3b, 0x31, 0x4d]
                    bridge.client.sendInput(seq)
                }

                // Horizontal: left/right arrow keys
                while accumulatedX > cursorThreshold {
                    accumulatedX -= cursorThreshold
                    // Arrow Right: \x1b[C
                    bridge.client.sendInput([0x1b, 0x5b, 0x43])
                }
                while accumulatedX < -cursorThreshold {
                    accumulatedX += cursorThreshold
                    // Arrow Left: \x1b[D
                    bridge.client.sendInput([0x1b, 0x5b, 0x44])
                }
            case .ended, .cancelled:
                accumulatedY = 0
                accumulatedX = 0
            default:
                break
            }
        }
    }
}
