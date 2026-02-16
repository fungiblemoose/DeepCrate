import SwiftUI

@main
struct DeepCrateMacApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup("DeepCrate") {
            RootView()
                .environmentObject(appState)
                .environmentObject(settings)
        }
        .defaultSize(width: 1320, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Music Folder") {
                    appState.statusMessage = "Use Library -> Choose Folder"
                }
                .keyboardShortcut("o")

                Button("Scan Current Folder") {
                    appState.statusMessage = "Open Library and click Scan."
                }
                .keyboardShortcut("r")
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}
