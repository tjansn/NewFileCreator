import Cocoa
import Carbon.HIToolbox

/// A system-wide hotkey backed by Carbon's `RegisterEventHotKey`.
///
/// Carbon hotkeys are the only way to register a global shortcut that (a) works
/// from a background `LSUIElement` agent, (b) consumes the key event, and (c)
/// requires no Accessibility / Input Monitoring permission. The modern
/// `NSEvent.addGlobalMonitorForEvents` alternative needs Accessibility and cannot
/// consume the event, so it's unsuitable here.
final class GlobalHotKey {

    private static var registry: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false
    private static let signature: OSType = 0x4E464331 // 'NFC1'

    private let id: UInt32
    private var hotKeyRef: EventHotKeyRef?

    /// - Parameters:
    ///   - keyCode: a virtual key code, e.g. `kVK_ANSI_N`.
    ///   - carbonModifiers: Carbon modifier mask, e.g. `controlKey | optionKey | cmdKey`.
    ///   - onFire: invoked on the main thread when the hotkey is pressed.
    init?(keyCode: UInt32, carbonModifiers: UInt32, onFire: @escaping () -> Void) {
        GlobalHotKey.installSharedHandlerIfNeeded()

        id = GlobalHotKey.nextID
        GlobalHotKey.nextID += 1
        GlobalHotKey.registry[id] = onFire

        let hotKeyID = EventHotKeyID(signature: GlobalHotKey.signature, id: id)
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            GlobalHotKey.registry[id] = nil
            return nil
        }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        GlobalHotKey.registry[id] = nil
    }

    private static func installSharedHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                guard let event else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if status == noErr {
                    GlobalHotKey.registry[hotKeyID.id]?()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }
}

/// Resolves the folder Finder would create a new item in right now.
///
/// Finder's AppleScript `insertion location` returns the frontmost Finder window's
/// folder, or the Desktop when the Desktop is active / no window is open — which is
/// exactly the behavior we want for a global "new file" shortcut, and it covers the
/// Desktop that the Finder Sync menu cannot.
enum FinderLocation {
    static func insertionPath() -> String? {
        let source = """
        tell application "Finder"
            try
                return POSIX path of (insertion location as alias)
            on error
                return POSIX path of (path to desktop folder)
            end try
        end tell
        """

        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            NSLog("NewFileCreator: Finder insertion location failed: \(error)")
            return nil
        }
        return result.stringValue
    }
}
