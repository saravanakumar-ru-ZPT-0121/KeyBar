import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService` for toggling "launch Keybar at login".
/// No helper app or entitlement is required for a main-app login item.
enum LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Attempts to enable/disable launch at login. Returns whether the
    /// resulting state matches what was requested.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("LaunchAtLoginManager: failed to \(enabled ? "register" : "unregister"): \(error)")
        }
        return isEnabled == enabled
    }
}
