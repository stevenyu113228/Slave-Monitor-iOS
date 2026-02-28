import SwiftUI

struct DeviceTabBar: View {
    @Environment(AppState.self) private var appState
    let onAdd: () -> Void
    let onEdit: (DeviceProfile) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(appState.profiles) { profile in
                    deviceTab(for: profile)
                }

                // Add device button
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(white: 0.18))
                        )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
    }

    @ViewBuilder
    private func deviceTab(for profile: DeviceProfile) -> some View {
        let isSelected = appState.selectedProfileID == profile.id
        let connection = appState.activeConnections[profile.id]
        let status = connection?.connectionStatus ?? .disconnected

        Button {
            appState.selectedProfileID = profile.id
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor(for: status))
                    .frame(width: 7, height: 7)
                Text(profile.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? Color(white: 0.25)
                          : Color(white: 0.14))
            )
        }
        .contextMenu {
            Button {
                onEdit(profile)
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                if let conn = appState.activeConnections[profile.id] {
                    conn.disconnect()
                    conn.connect()
                }
            } label: {
                Label("Reconnect", systemImage: "arrow.clockwise")
            }

            Button {
                appState.activeConnections[profile.id]?.disconnect()
            } label: {
                Label("Disconnect", systemImage: "xmark.circle")
            }

            Divider()

            Button(role: .destructive) {
                appState.deleteProfile(profile.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func statusColor(for status: ConnectionStatus) -> Color {
        switch status {
        case .connected: .green
        case .connecting: .orange
        case .disconnected: .red
        case .kicked: .purple
        }
    }
}
