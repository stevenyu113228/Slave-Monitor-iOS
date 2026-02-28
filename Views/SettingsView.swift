import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var ip = ""
    @State private var ttydPort = ""
    @State private var apiPort = ""
    @State private var tmuxSession = ""
    @State private var fontSize: Double = 14
    @State private var testResult = ""
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    HStack {
                        Text("Tailscale IP")
                            .foregroundStyle(.secondary)
                        TextField("100.x.y.z", text: $ip)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    HStack {
                        Text("ttyd Port")
                            .foregroundStyle(.secondary)
                        TextField("7681", text: $ttydPort)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    HStack {
                        Text("API Port")
                            .foregroundStyle(.secondary)
                        TextField("8080", text: $apiPort)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    HStack {
                        Text("tmux Session")
                            .foregroundStyle(.secondary)
                        TextField("claude", text: $tmuxSession)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }

                Section("Terminal") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Font Size")
                            Spacer()
                            Text("\(Int(fontSize))pt")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $fontSize, in: 10...24, step: 1)
                    }
                }

                Section("Test") {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if isTesting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(ip.isEmpty || isTesting)

                    if !testResult.isEmpty {
                        Text(testResult)
                            .font(.caption)
                            .foregroundStyle(testResult.contains("Success") ? .green : .red)
                    }
                }

                Section("About") {
                    HStack {
                        Text("App")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Claude Code Remote")
                    }
                    HStack {
                        Text("Terminal")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("SwiftTerm")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { loadSettings() }
            .preferredColorScheme(.dark)
        }
    }

    private func loadSettings() {
        ip = appState.tailscaleIP
        ttydPort = String(appState.ttydPort)
        apiPort = String(appState.apiPort)
        tmuxSession = appState.tmuxSession
        fontSize = Double(appState.fontSize)
    }

    private func save() {
        appState.tailscaleIP = ip
        appState.ttydPort = Int(ttydPort) ?? 7681
        appState.apiPort = Int(apiPort) ?? 8080
        appState.tmuxSession = tmuxSession
        appState.fontSize = CGFloat(fontSize)
        appState.apiClient.baseURL = appState.apiBaseURL
        dismiss()
    }

    private func testConnection() {
        isTesting = true
        testResult = ""

        Task {
            do {
                // Test ttyd token endpoint
                let port = Int(ttydPort) ?? 7681
                let url = URL(string: "http://\(ip):\(port)/token")!
                let (_, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    testResult = "Success: ttyd reachable"
                } else {
                    testResult = "Error: unexpected response"
                }
            } catch {
                testResult = "Error: \(error.localizedDescription)"
            }
            isTesting = false
        }
    }
}
