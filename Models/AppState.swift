import SwiftUI

enum ConnectionStatus: String {
    case disconnected
    case connecting
    case connected
}

@Observable
class AppState {
    var connectionStatus: ConnectionStatus = .disconnected
    var tailscaleIP: String {
        get { UserDefaults.standard.string(forKey: "tailscaleIP") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "tailscaleIP") }
    }
    var ttydPort: Int {
        get { UserDefaults.standard.integer(forKey: "ttydPort").nonZero ?? 7681 }
        set { UserDefaults.standard.set(newValue, forKey: "ttydPort") }
    }
    var apiPort: Int {
        get { UserDefaults.standard.integer(forKey: "apiPort").nonZero ?? 8080 }
        set { UserDefaults.standard.set(newValue, forKey: "apiPort") }
    }
    var tmuxSession: String {
        get { UserDefaults.standard.string(forKey: "tmuxSession") ?? "claude" }
        set { UserDefaults.standard.set(newValue, forKey: "tmuxSession") }
    }
    var fontSize: CGFloat {
        get {
            let stored = UserDefaults.standard.double(forKey: "fontSize")
            return stored > 0 ? CGFloat(stored) : 14.0
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: "fontSize") }
    }

    let client = TtydClient()
    let apiClient = APIClient()

    var apiBaseURL: String {
        "http://\(tailscaleIP):\(apiPort)"
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
