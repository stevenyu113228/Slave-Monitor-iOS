import SwiftUI

@main
struct ClaudeRemoteApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
    }
}
