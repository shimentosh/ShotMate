import AppKit
import SwiftUI

/// Plain-language error alerts.
enum Alerts {
    static func show(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again."
        show(title: "ShotMate", message: message)
    }

    static func show(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

/// A brief confirmation bubble ("Copied to Clipboard") that never takes focus.
enum HUD {
    private static var panel: NSPanel?
    private static var dismissWork: DispatchWorkItem?

    static func show(_ message: String, symbol: String) {
        dismiss()

        let host = NSHostingView(rootView: HUDView(message: message, symbol: symbol))
        let size = host.fittingSize
        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(CGPoint(x: frame.midX - size.width / 2, y: frame.minY + 80))
        }
        panel.orderFrontRegardless()
        self.panel = panel

        let work = DispatchWorkItem { fadeOut() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: work)
    }

    static func dismiss() {
        dismissWork?.cancel()
        dismissWork = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private static func fadeOut() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: {
            if self.panel === panel { dismiss() }
        })
    }
}

private struct HUDView: View {
    let message: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.green)
            Text(message)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(.regularMaterial))
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
        .padding(1)
    }
}

/// Hover tracking for custom buttons. (A reference type rather than `@State`, which
/// needs the SwiftUI macro plugin that ships only with full Xcode.)
final class HoverState: ObservableObject {
    @Published var isHovering = false
}
