import SwiftUI

enum ConnectionStatus: String {
    case disconnected
    case connecting
    case connected
    case kicked       // Taken over by another device — don't auto-reconnect
}

@Observable
class AppState {
    var profiles: [DeviceProfile] = [] {
        didSet { Self.saveProfiles(profiles) }
    }

    var selectedProfileID: UUID? = nil {
        didSet { UserDefaults.standard.set(selectedProfileID?.uuidString, forKey: "selectedProfileID") }
    }

    var fontSize: CGFloat = 14.0 {
        didSet { UserDefaults.standard.set(Double(fontSize), forKey: "fontSize") }
    }

    var activeConnections: [UUID: DeviceConnection] = [:]

    var selectedProfile: DeviceProfile? {
        profiles.first { $0.id == selectedProfileID }
    }

    init() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "deviceProfiles"),
           let decoded = try? JSONDecoder().decode([DeviceProfile].self, from: data) {
            self.profiles = decoded
        }
        if let str = UserDefaults.standard.string(forKey: "selectedProfileID") {
            self.selectedProfileID = UUID(uuidString: str)
        }
        let stored = UserDefaults.standard.double(forKey: "fontSize")
        if stored > 0 { self.fontSize = CGFloat(stored) }
    }

    private static func saveProfiles(_ profiles: [DeviceProfile]) {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: "deviceProfiles")
        }
    }

    // MARK: - Connection Management

    func connectionFor(profile: DeviceProfile) -> DeviceConnection {
        if let existing = activeConnections[profile.id] {
            return existing
        }
        let connection = DeviceConnection(profile: profile)
        activeConnections[profile.id] = connection
        return connection
    }

    func disconnectAll() {
        for (_, connection) in activeConnections {
            connection.disconnect()
        }
        activeConnections.removeAll()
    }

    // MARK: - CRUD

    func addProfile(_ profile: DeviceProfile) {
        profiles.append(profile)
        selectedProfileID = profile.id
    }

    func updateProfile(_ profile: DeviceProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            let old = profiles[idx]
            profiles[idx] = profile

            // If connection params changed, reconnect
            if old.tailscaleIP != profile.tailscaleIP ||
               old.ttydPort != profile.ttydPort ||
               old.apiPort != profile.apiPort {
                if let conn = activeConnections[profile.id] {
                    conn.disconnect()
                    activeConnections.removeValue(forKey: profile.id)
                }
            }
        }
    }

    func deleteProfile(_ id: UUID) {
        if let conn = activeConnections[id] {
            conn.disconnect()
            activeConnections.removeValue(forKey: id)
        }
        profiles.removeAll { $0.id == id }
        if selectedProfileID == id {
            selectedProfileID = profiles.first?.id
        }
    }

    // MARK: - Migration

    func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        guard let ip = defaults.string(forKey: "tailscaleIP"), !ip.isEmpty else { return }
        // Already migrated?
        if !profiles.isEmpty { return }

        let ttydPort = defaults.integer(forKey: "ttydPort").nonZero ?? 7681
        let apiPort = defaults.integer(forKey: "apiPort").nonZero ?? 8080
        let tmuxSession = defaults.string(forKey: "tmuxSession") ?? "claude"

        let profile = DeviceProfile(
            name: "My Mac",
            tailscaleIP: ip,
            ttydPort: ttydPort,
            apiPort: apiPort,
            tmuxSession: tmuxSession
        )
        addProfile(profile)

        // Clean up old keys
        defaults.removeObject(forKey: "tailscaleIP")
        defaults.removeObject(forKey: "ttydPort")
        defaults.removeObject(forKey: "apiPort")
        defaults.removeObject(forKey: "tmuxSession")
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
