import AppKit

/// Runs one capture session from hotkey to clipboard. Each display gets its own
/// overlay, and the selection is confined to the display the drag starts on.
@MainActor
final class CaptureCoordinator {
    static let shared = CaptureCoordinator()

    /// Lets the menu bar close its popover before the screen is frozen.
    var willBeginCapture: (() -> Void)?

    private(set) var isCapturing = false
    private var windows: [CaptureOverlayWindow] = []
    private var overlays: [CaptureOverlayView] = []
    private var previousApp: NSRunningApplication?
    private var screenObserver: NSObjectProtocol?

    private init() {}

    func start() {
        guard !isCapturing else { return }
        guard ScreenPermission.isGranted else {
            PermissionWindowController.shared.show()
            return
        }

        isCapturing = true
        willBeginCapture?()
        HUD.dismiss()
        previousApp = NSWorkspace.shared.frontmostApplication.flatMap { $0 == .current ? nil : $0 }

        Task { @MainActor in
            do {
                let shots = try await ScreenCaptureManager.shared.captureAllScreens()
                present(shots)
            } catch CaptureError.permissionDenied {
                isCapturing = false
                PermissionWindowController.shared.show()
            } catch {
                isCapturing = false
                Alerts.show(error)
            }
        }
    }

    func cancel() {
        close(restoreFocus: true)
    }

    /// Returns false when another display already holds annotations, so a stray
    /// drag on a second monitor can't discard the user's work.
    func overlayWillBeginSelection(_ overlay: CaptureOverlayView) -> Bool {
        let others = overlays.filter { $0 !== overlay }
        guard !others.contains(where: \.hasAnnotations) else { return false }
        others.filter(\.hasSelection).forEach { $0.clearSelection() }
        return true
    }

    func finish(_ output: CaptureOutput, from overlay: CaptureOverlayView) {
        guard let screenshot = overlay.renderScreenshot() else { return }

        let action: AfterCaptureAction = switch output {
        case .primary: AppSettings.shared.afterCapture
        case .copy: .copy
        case .saveAs: .save
        }

        if output == .saveAs {
            saveWithPanel(screenshot)
            return
        }

        do {
            switch action {
            case .copy:
                try ClipboardManager.copy(screenshot)
                close(restoreFocus: true)
                HUD.show("Copied to Clipboard", symbol: "checkmark.circle.fill")
            case .save:
                let url = try ImageSaver.saveToDefaultLocation(screenshot)
                close(restoreFocus: true)
                HUD.show("Saved to \(url.deletingLastPathComponent().lastPathComponent)", symbol: "checkmark.circle.fill")
            case .copyAndSave:
                try ClipboardManager.copy(screenshot)
                _ = try ImageSaver.saveToDefaultLocation(screenshot)
                close(restoreFocus: true)
                HUD.show("Copied and Saved", symbol: "checkmark.circle.fill")
            }
        } catch {
            close(restoreFocus: true)
            Alerts.show(error)
        }
    }

    // MARK: - Private

    private func present(_ shots: [CapturedScreen]) {
        let toolState = AnnotationToolState()
        let mouseLocation = NSEvent.mouseLocation
        var keyWindow: CaptureOverlayWindow?

        for shot in shots {
            let window = CaptureOverlayWindow(screen: shot.screen)
            let view = CaptureOverlayView(
                frame: CGRect(origin: .zero, size: shot.screen.frame.size),
                image: shot.image,
                toolState: toolState
            )
            view.coordinator = self
            window.contentView = view
            window.initialFirstResponder = view
            windows.append(window)
            overlays.append(view)
            if shot.screen.frame.contains(mouseLocation) {
                keyWindow = window
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        for window in windows where window !== keyWindow {
            window.orderFrontRegardless()
        }
        let key = keyWindow ?? windows.first
        key?.makeKeyAndOrderFront(nil)
        if let view = key?.contentView {
            key?.makeFirstResponder(view)
        }
        NSCursor.crosshair.set()

        // Unplugging a monitor mid-capture would leave overlays misaligned.
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.cancel() }
        }
    }

    private func saveWithPanel(_ screenshot: RenderedScreenshot) {
        windows.forEach { $0.orderOut(nil) }
        let result = ImageSaver.saveWithPanel(screenshot)
        switch result {
        case .saved:
            close(restoreFocus: true)
            HUD.show("Saved", symbol: "checkmark.circle.fill")
        case .cancelled:
            // Back to the capture, annotations intact.
            windows.forEach { $0.orderFrontRegardless() }
            windows.first(where: { ($0.contentView as? CaptureOverlayView)?.hasSelection == true })?.makeKey()
        case .failed(let error):
            close(restoreFocus: true)
            Alerts.show(error)
        }
    }

    private func close(restoreFocus: Bool) {
        guard isCapturing else { return }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        overlays.removeAll()
        isCapturing = false
        NSCursor.arrow.set()

        // Hand focus straight back to the app the user was in, ready for ⌘V.
        if restoreFocus, let previousApp, !previousApp.isTerminated {
            previousApp.activate()
        }
        previousApp = nil
    }
}
