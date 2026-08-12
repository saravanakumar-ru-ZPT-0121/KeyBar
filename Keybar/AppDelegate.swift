import AppKit
import SwiftUI

/// Persisted app-wide preferences (currently just the global shortcut).
final class AppSettings: ObservableObject {
    @Published var shortcut: KeyCombo {
        didSet {
            persist()
            GlobalShortcutManager.shared.register(shortcut)
        }
    }

    private static let defaultsKey = "com.keybar.globalShortcut"

    init() {
        if
            let data = UserDefaults.standard.data(forKey: AppSettings.defaultsKey),
            let decoded = try? JSONDecoder().decode(KeyCombo.self, from: data)
        {
            shortcut = decoded
        } else {
            shortcut = .default
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        UserDefaults.standard.set(data, forKey: AppSettings.defaultsKey)
    }
}

/// Owns the status bar item and popover. We use `NSStatusItem` + `NSPopover`
/// directly (rather than `MenuBarExtra`) because we need to open the dropdown
/// programmatically from a global keyboard shortcut, which `MenuBarExtra`
/// does not support on macOS 13.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    private let accountStore = AccountStore()
    private let appSettings = AppSettings()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // No Dock icon, no app switcher entry.

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "key.fill", accessibilityDescription: "Keybar")
            button.action = #selector(togglePopover)
            button.target = self
        }
        statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 440)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView(appSettings: appSettings)
                .environmentObject(accountStore)
        )
        self.popover = popover

        GlobalShortcutManager.shared.onTrigger = { [weak self] in
            self?.showPopover()
        }
        GlobalShortcutManager.shared.register(appSettings.shortcut)

        NotificationCenter.default.addObserver(
            forName: .keybarDidCopyCode,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.closePopoverAfterCopy()
        }
    }

    @objc private func togglePopover() {
        guard let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let popover, let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    /// Closes the popover right after a code is copied, with just enough delay
    /// for the checkmark confirmation to be visible.
    private func closePopoverAfterCopy() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.popover?.performClose(nil)
        }
    }
}
