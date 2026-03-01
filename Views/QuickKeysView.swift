import SwiftUI

struct QuickKeysView: View {
    let client: TtydClient

    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        HStack(spacing: 4) {
            // Left: two rows of keys
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    keyButton("/", bytes: Array("/".utf8))
                    keyButton("▲", bytes: [0x1B, 0x5B, 0x41])
                    keyButton("▼", bytes: [0x1B, 0x5B, 0x42])
                    keyButton("Tab", bytes: [0x09])
                    keyButton("Esc", bytes: [0x1B])
                    keyButton("Enter", bytes: [0x0D])
                }
                HStack(spacing: 4) {
                    keyButton("⇧Tab", bytes: [0x1B, 0x5B, 0x5A])
                    keyButton("Ctrl+C", bytes: [0x03])
                    keyButton("Ctrl+O", bytes: [0x0F])
                    keyButton("Ctrl+U", bytes: [0x15])
                }
            }
            .frame(maxWidth: .infinity)

            // Right: tall Backspace spanning both rows
            Button {
                haptic.impactOccurred()
                client.sendInput([0x7F])
            } label: {
                Text("⌫")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxHeight: .infinity)
                    .frame(width: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(white: 0.2))
                    )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Color(red: 0.13, green: 0.13, blue: 0.13))
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
