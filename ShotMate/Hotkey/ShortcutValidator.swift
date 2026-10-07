import AppKit
import Carbon.HIToolbox

enum ShortcutValidation: Equatable {
    case ok
    /// Usable, but macOS may intercept it first.
    case warning(String)
    case invalid(String)
}

/// Rejects shortcuts that would break normal typing or standard app commands, and
/// flags ones that collide with macOS's own keyboard shortcuts.
enum ShortcutValidator {
    /// Plain ⌘ shortcuts that nearly every app relies on.
    private static let reservedCommandKeys: Set<Int> = [
        kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_C, kVK_ANSI_V, kVK_ANSI_X, kVK_ANSI_Z, kVK_ANSI_A,
        kVK_ANSI_S, kVK_ANSI_O, kVK_ANSI_N, kVK_ANSI_P, kVK_ANSI_F, kVK_ANSI_T, kVK_ANSI_H,
        kVK_ANSI_M, kVK_ANSI_Comma
    ]

    static func validate(_ combo: KeyCombo) -> ShortcutValidation {
        let flags = combo.modifierFlags
        let key = Int(combo.keyCode)

        if KeyCombo.modifierKeyCodes.contains(key) {
            return .invalid("Press a key together with the modifiers.")
        }
        if key == kVK_Escape {
            return .invalid("Escape is used to cancel a capture. Choose a different key.")
        }
        if flags.intersection([.command, .option, .control]).isEmpty && !combo.isFunctionKey {
            return .invalid("Include ⌘, ⌥ or ⌃ so the shortcut doesn't get in the way of typing.")
        }
        if flags == [.command] && reservedCommandKeys.contains(key) {
            return .invalid("\(combo.displayString) is a standard Mac shortcut used by most apps. Choose a different one.")
        }
        if flags.contains(.command) && (key == kVK_Tab || key == kVK_Space) {
            return .invalid("\(combo.displayString) is reserved by macOS. Choose a different one.")
        }
        if let feature = systemFeature(using: combo) {
            return .warning("macOS also uses \(combo.displayString) for \(feature). Turn it off in System Settings › Keyboard › Keyboard Shortcuts so ShotMate receives it.")
        }
        return .ok
    }

    /// Names the macOS feature bound to `combo`, if it is an enabled system shortcut.
    private static func systemFeature(using combo: KeyCombo) -> String? {
        let screenshotKeys: Set<Int> = [kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5]
        let flags = combo.modifierFlags
        let isScreenshotCombo = screenshotKeys.contains(Int(combo.keyCode))
            && (flags == [.command, .shift] || (flags == [.command, .shift, .control] && combo.keyCode != UInt32(kVK_ANSI_5)))

        guard isEnabledSymbolicHotKey(combo) || isScreenshotCombo else { return nil }
        return isScreenshotCombo ? "Screenshots" : "a system shortcut"
    }

    private static func isEnabledSymbolicHotKey(_ combo: KeyCombo) -> Bool {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr,
              let hotKeys = unmanaged?.takeRetainedValue() as? [[String: Any]] else {
            return false
        }
        let relevantModifiers = UInt32(cmdKey | optionKey | controlKey | shiftKey)
        return hotKeys.contains { entry in
            guard (entry["kHISymbolicHotKeyEnabled"] as? Bool) == true,
                  let code = (entry["kHISymbolicHotKeyCode"] as? NSNumber)?.uint32Value,
                  let modifiers = (entry["kHISymbolicHotKeyModifiers"] as? NSNumber)?.uint32Value else {
                return false
            }
            return code == combo.keyCode && (modifiers & relevantModifiers) == combo.carbonModifiers
        }
    }
}
