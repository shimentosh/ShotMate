import AppKit
import SwiftUI

/// Observable copy of the permission state, refreshed whenever the popover opens.
final class PermissionStatus: ObservableObject {
    @Published var isGranted = ScreenPermission.isGranted

    func refresh() {
        isGranted = ScreenPermission.isGranted
    }
}

/// Owns the menu bar icon and its compact popover.
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let recorder = ShortcutRecorder()
    private let permission = PermissionStatus()

    init(onCapture: @escaping () -> Void) {
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "ShotMate")
            image?.isTemplate = true
            button.image = image?.withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
            button.target = self
            button.action = #selector(togglePopover)
            button.toolTip = "ShotMate"
        }

        let view = MenuBarView(
            recorder: recorder,
            permission: permission,
            onCapture: { [weak self] in
                self?.closePopover()
                // Let the popover leave the screen before the display is frozen.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: onCapture)
            },
            onGrantPermission: { [weak self] in
                self?.closePopover()
                PermissionWindowController.shared.show()
            },
            onQuit: { NSApp.terminate(nil) }
        )
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = .preferredContentSize
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.delegate = self
    }

    func closePopover() {
        guard popover.isShown else { return }
        let animates = popover.animates
        popover.animates = false
        popover.performClose(nil)
        popover.animates = animates
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        permission.refresh()
        LaunchAtLogin.shared.refresh()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        recorder.cancel()
        recorder.message = nil
    }
}
