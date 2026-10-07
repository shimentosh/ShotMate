import AppKit
import Carbon.HIToolbox

/// Listens for the next key combination while the user is changing the shortcut.
///
/// The current global hot key is suspended while recording so pressing it is
/// recorded instead of starting a capture.
final class ShortcutRecorder: ObservableObject {
    struct Message: Equatable {
        enum Kind { case error, warning, info }
        let text: String
        let kind: Kind
    }

    @Published private(set) var isRecording = false
    @Published private(set) var liveModifiers: NSEvent.ModifierFlags = []
    @Published var message: Message?

    private var monitor: Any?
    private let settings = AppSettings.shared

    func start() {
        guard !isRecording else { return }
        message = nil
        liveModifiers = []
        isRecording = true
        GlobalHotkeyManager.shared.unregister()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            self.handle(event)
            return nil
        }
    }

    func cancel() {
        guard isRecording else { return }
        stop()
        restoreCurrentShortcut()
    }

    func resetToDefault() {
        cancel()
        apply(.default)
    }

    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
        liveModifiers = []
    }

    private func handle(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(KeyCombo.supportedModifiers)
        if event.type == .flagsChanged {
            liveModifiers = modifiers
            return
        }
        guard !event.isARepeat else { return }

        if Int(event.keyCode) == kVK_Escape && modifiers.isEmpty {
            cancel()
            return
        }
        apply(KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers))
    }

    private func apply(_ combo: KeyCombo) {
        let validation = ShortcutValidator.validate(combo)
        if case .invalid(let reason) = validation {
            message = Message(text: reason, kind: .error)
            return
        }

        do {
            try GlobalHotkeyManager.shared.register(combo)
        } catch {
            message = Message(text: "Another app is already using \(combo.displayString). Try a different shortcut.", kind: .error)
            if !isRecording { restoreCurrentShortcut() }
            return
        }

        stop()
        settings.shortcut = combo
        if case .warning(let text) = validation {
            message = Message(text: text, kind: .warning)
        } else {
            message = nil
        }
    }

    private func restoreCurrentShortcut() {
        do {
            try GlobalHotkeyManager.shared.register(settings.shortcut)
        } catch {
            message = Message(text: "\(settings.shortcut.displayString) is in use by another app. Choose a different shortcut.", kind: .error)
        }
    }
}
