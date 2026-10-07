import AppKit
import SwiftUI

/// Screen Recording (TCC) permission helpers.
enum ScreenPermission {
    static var isGranted: Bool { CGPreflightScreenCaptureAccess() }

    private static let onboardingKey = "hasShownPermissionOnboarding"

    static var hasShownOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingKey) }
    }

    static func openSystemSettings() {
        // Registers ShotMate in the Screen Recording list so the user only has to flip the switch.
        _ = CGRequestScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// macOS applies a newly granted Screen Recording permission after the app restarts.
    static func relaunch() {
        let bundlePath = Bundle.main.bundlePath
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            NSApp.terminate(nil)
            return
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5; /usr/bin/open \"$0\"", bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}

final class PermissionWindowController {
    static let shared = PermissionWindowController()

    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.contentView = NSHostingView(rootView: PermissionView(close: { [weak self] in self?.close() }))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }
}

private struct PermissionView: View {
    let close: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "viewfinder")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.accentColor.gradient))

            VStack(spacing: 6) {
                Text("ShotMate needs Screen Recording permission\nto capture your screen.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Turn on ShotMate in System Settings, then reopen ShotMate. Screenshots never leave your Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                Button {
                    ScreenPermission.openSystemSettings()
                } label: {
                    Text("Open System Settings").frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)

                HStack {
                    Button("Not Now", action: close)
                        .buttonStyle(.borderless)
                    Spacer()
                    Button("Reopen ShotMate") { ScreenPermission.relaunch() }
                        .buttonStyle(.borderless)
                }
                .font(.callout)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 30)
        .padding(.bottom, 18)
        .frame(width: 380)
    }
}
