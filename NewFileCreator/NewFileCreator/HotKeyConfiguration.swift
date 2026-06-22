import Cocoa
import Carbon.HIToolbox

/// A user-configurable global shortcut: a virtual key plus a Carbon modifier mask,
/// along with a display string (e.g. "⌃⌥⌘N") for the UI.
struct HotKeyShortcut: Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var displayString: String
}

/// Persists the file-creation shortcuts in `UserDefaults` and supplies defaults.
enum HotKeyStore {
    /// The actions that can be bound to a shortcut. Each maps to a file type.
    enum Action: String, CaseIterable {
        case text
        case markdown

        var title: String {
            switch self {
            case .text: return "New Text File"
            case .markdown: return "New Markdown File"
            }
        }

        var defaultShortcut: HotKeyShortcut {
            switch self {
            case .text:
                return HotKeyShortcut(
                    keyCode: UInt32(kVK_ANSI_N),
                    carbonModifiers: UInt32(controlKey | optionKey | cmdKey),
                    displayString: "⌃⌥⌘N"
                )
            case .markdown:
                return HotKeyShortcut(
                    keyCode: UInt32(kVK_ANSI_M),
                    carbonModifiers: UInt32(controlKey | optionKey | cmdKey),
                    displayString: "⌃⌥⌘M"
                )
            }
        }
    }

    private static let defaults = UserDefaults.standard

    /// Returns the configured shortcut, the default if never set, or nil if the user
    /// disabled it.
    static func shortcut(for action: Action) -> HotKeyShortcut? {
        let prefix = key(action)
        if defaults.bool(forKey: "\(prefix).disabled") {
            return nil
        }
        guard defaults.object(forKey: "\(prefix).keyCode") != nil else {
            return action.defaultShortcut
        }
        return HotKeyShortcut(
            keyCode: UInt32(defaults.integer(forKey: "\(prefix).keyCode")),
            carbonModifiers: UInt32(defaults.integer(forKey: "\(prefix).modifiers")),
            displayString: defaults.string(forKey: "\(prefix).display") ?? ""
        )
    }

    /// Stores a shortcut, or marks the action disabled when passed nil.
    static func setShortcut(_ shortcut: HotKeyShortcut?, for action: Action) {
        let prefix = key(action)
        if let shortcut {
            defaults.set(Int(shortcut.keyCode), forKey: "\(prefix).keyCode")
            defaults.set(Int(shortcut.carbonModifiers), forKey: "\(prefix).modifiers")
            defaults.set(shortcut.displayString, forKey: "\(prefix).display")
            defaults.set(false, forKey: "\(prefix).disabled")
        } else {
            defaults.set(true, forKey: "\(prefix).disabled")
        }
    }

    static func resetToDefaults() {
        for action in Action.allCases {
            let prefix = key(action)
            for suffix in ["keyCode", "modifiers", "display", "disabled"] {
                defaults.removeObject(forKey: "\(prefix).\(suffix)")
            }
        }
    }

    private static func key(_ action: Action) -> String {
        "hotkey.\(action.rawValue)"
    }
}

/// Converts between AppKit modifier flags (used while recording) and the Carbon
/// representation (`RegisterEventHotKey`) and a human-readable display string.
enum ShortcutFormatter {
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    /// Builds the Apple-ordered display string (⌃⌥⇧⌘) followed by the key.
    static func displayString(flags: NSEvent.ModifierFlags, key: String) -> String {
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        result += key.uppercased()
        return result
    }
}

extension Notification.Name {
    static let hotKeysChanged = Notification.Name("io.github.tjansn.NewFileCreator.hotKeysChanged")
}
