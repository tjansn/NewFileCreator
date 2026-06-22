import Cocoa
import Carbon.HIToolbox

/// A button that records a global shortcut. Clicking it captures the next key
/// combination (which must include at least one modifier); Escape cancels.
final class ShortcutRecorderButton: NSButton {

    var onRecord: ((HotKeyShortcut) -> Void)?

    var shortcut: HotKeyShortcut? {
        didSet { updateTitle() }
    }

    private var isRecording = false
    private var monitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggleRecording)
        updateTitle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateTitle() {
        if isRecording {
            title = "Type shortcut… (⎋ to cancel)"
        } else {
            title = shortcut?.displayString ?? "Click to record"
        }
    }

    @objc private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        updateTitle()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }

            if event.keyCode == UInt16(kVK_Escape) {
                self.stopRecording()
                return nil
            }

            let modifiers = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .intersection([.command, .option, .control, .shift])

            guard !modifiers.isEmpty else {
                NSSound.beep() // require at least one modifier to avoid clashing with typing
                return nil
            }

            guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
                return nil
            }

            let recorded = HotKeyShortcut(
                keyCode: UInt32(event.keyCode),
                carbonModifiers: ShortcutFormatter.carbonModifiers(from: modifiers),
                displayString: ShortcutFormatter.displayString(flags: modifiers, key: characters)
            )
            self.shortcut = recorded
            self.stopRecording()
            self.onRecord?(recorded)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        updateTitle()
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

/// Lets the user enable/disable and rebind the global file-creation shortcuts.
/// Shown when the user reopens the (otherwise headless) app.
final class PreferencesWindowController: NSWindowController {

    private var recorders: [HotKeyStore.Action: ShortcutRecorderButton] = [:]
    private var checkboxes: [HotKeyStore.Action: NSButton] = [:]

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "New File Creator Settings"
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
        buildContent()
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let titleLabel = NSTextField(labelWithString: "Global Shortcuts")
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        var rows: [NSView] = [titleLabel]

        for action in HotKeyStore.Action.allCases {
            let current = HotKeyStore.shortcut(for: action)

            let checkbox = NSButton(checkboxWithTitle: action.title, target: self, action: #selector(toggleAction(_:)))
            checkbox.state = (current != nil) ? .on : .off
            checkbox.identifier = NSUserInterfaceItemIdentifier(action.rawValue)
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            checkbox.widthAnchor.constraint(equalToConstant: 190).isActive = true
            checkboxes[action] = checkbox

            let recorder = ShortcutRecorderButton(frame: .zero)
            recorder.shortcut = current
            recorder.isEnabled = (current != nil)
            recorder.translatesAutoresizingMaskIntoConstraints = false
            recorder.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
            recorder.onRecord = { [weak self] shortcut in
                HotKeyStore.setShortcut(shortcut, for: action)
                self?.notifyChanged()
            }
            recorders[action] = recorder

            let row = NSStackView(views: [checkbox, recorder])
            row.orientation = .horizontal
            row.spacing = 12
            rows.append(row)
        }

        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetDefaults))
        resetButton.bezelStyle = .rounded
        rows.append(resetButton)

        let note = NSTextField(wrappingLabelWithString:
            "Each shortcut creates a file in the folder Finder is showing — including the Desktop. "
            + "The first use asks for permission to control Finder.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        rows.append(note)

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),
            note.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    @objc private func toggleAction(_ sender: NSButton) {
        guard
            let raw = sender.identifier?.rawValue,
            let action = HotKeyStore.Action(rawValue: raw)
        else { return }

        let recorder = recorders[action]
        if sender.state == .on {
            let shortcut = recorder?.shortcut ?? action.defaultShortcut
            recorder?.shortcut = shortcut
            recorder?.isEnabled = true
            HotKeyStore.setShortcut(shortcut, for: action)
        } else {
            recorder?.isEnabled = false
            HotKeyStore.setShortcut(nil, for: action)
        }
        notifyChanged()
    }

    @objc private func resetDefaults() {
        HotKeyStore.resetToDefaults()
        for action in HotKeyStore.Action.allCases {
            let shortcut = HotKeyStore.shortcut(for: action)
            recorders[action]?.shortcut = shortcut
            recorders[action]?.isEnabled = (shortcut != nil)
            checkboxes[action]?.state = (shortcut != nil) ? .on : .off
        }
        notifyChanged()
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .hotKeysChanged, object: nil)
    }
}
