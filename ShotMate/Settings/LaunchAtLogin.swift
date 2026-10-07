import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp` so the menu bar toggle reflects the real system state.
final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()

    @Published private(set) var isEnabled = false
    @Published private(set) var needsApproval = false
    @Published var errorMessage: String?

    private static let defaultAppliedKey = "launchAtLoginDefaultApplied"

    /// Login items only work for a real `.app` bundle (not a bare executable run from Xcode).
    var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    private init() { refresh() }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        needsApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = isAvailable
                ? "Couldn't change the login item. Try again from System Settings › General › Login Items."
                : "Launch at Login works when ShotMate runs as an app (build it with Scripts/build-app.sh)."
        }
        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Launch at Login defaults to ON the first time ShotMate runs as an app.
    func applyDefaultOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard isAvailable, !defaults.bool(forKey: Self.defaultAppliedKey) else { return }
        defaults.set(true, forKey: Self.defaultAppliedKey)
        if !isEnabled {
            setEnabled(true)
        }
    }
}
