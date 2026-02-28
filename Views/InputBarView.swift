import SwiftUI

struct InputBarView: View {
    let client: TtydClient
    @Environment(AppState.self) private var appState
    @State private var text = ""
    @State private var showPhotoPicker = false
    @State private var showQuickCommands = false

    var body: some View {
        HStack(spacing: 6) {
            // Quick commands button
            Button {
                showQuickCommands = true
            } label: {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
            }

            // Text field (iOS dictation works automatically)
            TextField("Dictate or type here...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(white: 0.35), lineWidth: 1)
                )
                .foregroundStyle(.white)
                .font(.system(size: 16))
                .lineLimit(1...4)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                .onSubmit { sendText() }

            // Send button
            Button("Send") {
                sendText()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
            )

            // Photo button
            Button {
                showPhotoPicker = true
            } label: {
                Text("\u{1F4F7}")
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView(client: client)
        }
        .sheet(isPresented: $showQuickCommands) {
            QuickCommandsView()
        }
    }

    private func sendText() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Replace [filename] placeholders with full paths
        let processed = trimmed.replacingOccurrences(
            of: #"\[([^\]]+\.(jpg|jpeg|png|gif|webp|heic))\]"#,
            with: "/tmp/claude-uploads/$1",
            options: .regularExpression
        )

        // Send text as bytes + Enter
        let bytes = Array(processed.utf8)
        client.sendInput(bytes)
        client.sendInput([0x0D]) // CR = Enter

        text = ""
    }
}
