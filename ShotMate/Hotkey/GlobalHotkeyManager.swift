import AppKit
import Carbon.HIToolbox

/// Registers the system-wide capture shortcut with the Carbon hot key API.
///
/// `RegisterEventHotKey` is still the supported way to own a global shortcut on macOS:
/// it needs no Accessibility permission and the key press is consumed, so it never
/// reaches the frontmost app.
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    enum RegistrationError: Error {
        case alreadyInUse
        case failed(OSStatus)
    }

    /// Called on the main thread whenever the shortcut is pressed.
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x5348_4D54), id: 1) // 'SHMT'

    private init() {}

    func register(_ combo: KeyCombo) throws {
        installHandlerIfNeeded()
        unregister()

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive),
            &ref
        )
        guard status == noErr, let ref else {
            throw status == OSStatus(eventHotKeyExistsErr) ? RegistrationError.alreadyInUse : RegistrationError.failed(status)
        }
        hotKeyRef = ref
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var pressedID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressedID
                )
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                guard status == noErr, pressedID.signature == manager.hotKeyID.signature else {
                    return OSStatus(eventNotHandledErr)
                }
                DispatchQueue.main.async { manager.onTrigger?() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }
}
