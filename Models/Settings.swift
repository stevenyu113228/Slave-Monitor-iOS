import Foundation

struct QuickCommand: Codable, Identifiable, Equatable {
    var id = UUID()
    var label: String
    var command: String
    var description: String
    var newWindow: Bool = false
}

class SettingsStore {
    static let shared = SettingsStore()

    private let quickCommandsKey = "quickCommands"

    var quickCommands: [QuickCommand] {
        get {
            guard let data = UserDefaults.standard.data(forKey: quickCommandsKey),
                  let commands = try? JSONDecoder().decode([QuickCommand].self, from: data)
            else {
                return Self.defaultCommands
            }
            return commands
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: quickCommandsKey)
            }
        }
    }

    static let defaultCommands: [QuickCommand] = [
        QuickCommand(label: "git status", command: "git status", description: "Show git status"),
        QuickCommand(label: "git diff", command: "git diff", description: "Show changes"),
        QuickCommand(label: "ls -la", command: "ls -la", description: "List files"),
        QuickCommand(label: "pwd", command: "pwd", description: "Current directory"),
        QuickCommand(label: "npm test", command: "npm test", description: "Run tests"),
    ]
}
