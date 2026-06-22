import Cocoa

/// Queries whether the Finder Sync extension is currently enabled.
///
/// There is no public API to read this from the containing app, so we shell out to
/// `pluginkit`. The leading flag in `pluginkit -m` output is `+` when the matching
/// extension is enabled.
enum ExtensionStatus {
    static let extensionIdentifier = "io.github.tjansn.NewFileCreator.NewFileExtension"

    static func isEnabled() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = ["-m", "-i", extensionIdentifier]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            NSLog("NewFileCreator: pluginkit query failed: \(error.localizedDescription)")
            return false
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return false }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first == "+"
    }
}

/// A small, headless-friendly onboarding window shown only when the Finder
/// extension is not yet enabled. macOS requires a one-time user toggle to enable a
/// Finder Sync extension (there is no supported API to flip it), so we make that
/// step frictionless: deep-link to the right Settings pane for the running OS and
/// live-poll until the toggle flips, then restart Finder.
final class OnboardingWindowController: NSWindowController {

    private let statusLabel = NSTextField(labelWithString: "")
    private let instructionsLabel = NSTextField(wrappingLabelWithString: "")
    private let openSettingsButton = NSButton()
    private let copyCommandButton = NSButton()
    private var pollTimer: Timer?
    private var didFinish = false

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "New File Creator"
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
        buildContent()
        startPolling()
    }

    // MARK: - UI

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let titleLabel = NSTextField(labelWithString: "Enable the Finder extension")
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        instructionsLabel.stringValue = instructionsText()
        instructionsLabel.font = .systemFont(ofSize: 13)
        instructionsLabel.textColor = .secondaryLabelColor

        statusLabel.stringValue = "Waiting for you to enable the extension…"
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)

        openSettingsButton.title = "Open Settings"
        openSettingsButton.bezelStyle = .rounded
        openSettingsButton.target = self
        openSettingsButton.action = #selector(openSettings)
        openSettingsButton.keyEquivalent = "\r"

        copyCommandButton.title = "Copy enable command"
        copyCommandButton.bezelStyle = .rounded
        copyCommandButton.target = self
        copyCommandButton.action = #selector(copyCommand)

        let buttonRow = NSStackView(views: [openSettingsButton, copyCommandButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12

        let stack = NSStackView(views: [titleLabel, instructionsLabel, buttonRow, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),
            instructionsLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func instructionsText() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.majorVersion == 15 && version.minorVersion < 2 {
            return "macOS 15.0–15.1 hid the Finder extensions panel (an Apple bug fixed in 15.2). "
                + "Update to macOS 15.2 or newer, or use the copy-command button below to enable it from Terminal."
        }
        if version.majorVersion >= 15 {
            return "Open System Settings, then go to General → Login Items & Extensions → "
                + "Extensions, and turn on New File Creator under Finder. This window updates automatically."
        }
        return "Open System Settings, then go to Privacy & Security → Extensions → "
            + "Finder Extensions, and turn on New File Creator. This window updates automatically."
    }

    // MARK: - Actions

    @objc private func openSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        for string in urls {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    @objc private func copyCommand() {
        let command = "pluginkit -e use -i \(ExtensionStatus.extensionIdentifier) && killall Finder"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        statusLabel.stringValue = "Command copied. Paste it into Terminal and press Return."
    }

    // MARK: - Polling

    private func startPolling() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkEnabled()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func checkEnabled() {
        guard !didFinish, ExtensionStatus.isEnabled() else { return }
        didFinish = true
        pollTimer?.invalidate()
        pollTimer = nil

        statusLabel.stringValue = "✅ All set — restarting Finder…"
        openSettingsButton.isEnabled = false
        copyCommandButton.isEnabled = false

        restartFinder()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.close()
        }
    }

    private func restartFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]
        try? process.run()
    }

    deinit {
        pollTimer?.invalidate()
    }
}
