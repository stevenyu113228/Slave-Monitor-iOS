import SwiftUI

struct QuickCommandsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var commands: [QuickCommand] = []
    @State private var showAddSheet = false
    @State private var newLabel = ""
    @State private var newCommand = ""
    @State private var newDescription = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Quick Commands") {
                    ForEach(commands) { cmd in
                        commandRow(cmd)
                    }
                    .onDelete(perform: deleteCommand)
                }

                Section {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add Custom Command", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Commands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                commands = SettingsStore.shared.quickCommands
            }
            .alert("Add Command", isPresented: $showAddSheet) {
                TextField("Label", text: $newLabel)
                TextField("Command", text: $newCommand)
                TextField("Description", text: $newDescription)
                Button("Add") { addCommand() }
                Button("Cancel", role: .cancel) { clearAddFields() }
            }
            .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private func commandRow(_ cmd: QuickCommand) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(cmd.label)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                // Execute in current window
                Button {
                    executeCommand(cmd.command, newWindow: false)
                } label: {
                    Image(systemName: "play.fill")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)

                // Execute in new window
                Button {
                    executeCommand(cmd.command, newWindow: true)
                } label: {
                    Image(systemName: "rectangle.badge.plus")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            if !cmd.description.isEmpty {
                Text(cmd.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func executeCommand(_ command: String, newWindow: Bool) {
        Task {
            if newWindow {
                try? await appState.apiClient.newWindow()
                // Small delay for window creation
                try? await Task.sleep(for: .milliseconds(300))
            }
            try? await appState.apiClient.execCommand(command)
            dismiss()
        }
    }

    private func deleteCommand(at offsets: IndexSet) {
        commands.remove(atOffsets: offsets)
        SettingsStore.shared.quickCommands = commands
    }

    private func addCommand() {
        let cmd = QuickCommand(
            label: newLabel,
            command: newCommand,
            description: newDescription
        )
        commands.append(cmd)
        SettingsStore.shared.quickCommands = commands
        clearAddFields()
    }

    private func clearAddFields() {
        newLabel = ""
        newCommand = ""
        newDescription = ""
    }
}
