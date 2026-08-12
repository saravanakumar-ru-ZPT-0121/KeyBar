import SwiftUI

@main
struct KeybarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Keybar has no main window — the status bar item and its popover
        // (managed by AppDelegate) are the entire UI. This empty Settings
        // scene exists only because `App` requires at least one Scene.
        Settings {
            EmptyView()
        }
    }
}
