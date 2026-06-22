import Cocoa
import FinderSync
import ServiceManagement
import Carbon.HIToolbox

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!

    private var onboardingWindowController: OnboardingWindowController?
    private var preferencesWindowController: PreferencesWindowController?
    private var hotKeys: [GlobalHotKey] = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(registerGlobalHotKeys),
            name: .hotKeysChanged,
            object: nil
        )

        registerAsLoginItem()
        registerGlobalHotKeys()
        showOnboardingIfExtensionDisabled()
    }

    // Reopening the headless app (e.g. double-clicking it in Finder) opens Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showPreferences()
        return true
    }

    private func showPreferences() {
        let controller = preferencesWindowController ?? PreferencesWindowController()
        preferencesWindowController = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Registers the configured system-wide hotkeys to create a file in the folder
    /// Finder is currently showing — including the Desktop, which the Finder Sync
    /// context menu cannot reach. Carbon hotkeys work for background agent apps and
    /// need no Accessibility permission. Safe to call again to re-register after the
    /// configuration changes.
    @objc private func registerGlobalHotKeys() {
        hotKeys.removeAll() // GlobalHotKey unregisters itself on deinit
        registerHotKey(for: .text, kind: .text)
        registerHotKey(for: .markdown, kind: .markdown)
    }

    private func registerHotKey(for action: HotKeyStore.Action, kind: FileKind) {
        guard let shortcut = HotKeyStore.shortcut(for: action) else { return }
        if let hotKey = GlobalHotKey(
            keyCode: shortcut.keyCode,
            carbonModifiers: shortcut.carbonModifiers,
            onFire: { [weak self] in self?.createFileAtFinderLocation(kind: kind) }
        ) {
            hotKeys.append(hotKey)
        } else {
            NSLog("NewFileCreator: Failed to register \(action.rawValue) hotkey")
        }
    }

    private func createFileAtFinderLocation(kind: FileKind) {
        guard let path = FinderLocation.insertionPath() else {
            showError("Could not determine the current Finder folder.")
            return
        }

        let directory = URL(fileURLWithPath: path, isDirectory: true)
        do {
            let fileURL = try FileCreator.createFile(inDirectory: directory, fileKind: kind)
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } catch {
            NSLog("NewFileCreator: Hotkey file creation failed: \(error.localizedDescription)")
            showError(error.localizedDescription)
        }
    }

    // Keep the agent resident when the onboarding window closes. Staying alive is
    // what keeps NSWorkspace.open warm, so the next file creation is instant.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Registers this app to launch at login so it stays resident in the background
    /// (no Dock icon thanks to LSUIElement). A warm agent avoids the cold-launch
    /// latency of the URL round-trip that creates files.
    private func registerAsLoginItem() {
        let service = SMAppService.mainApp
        guard service.status != .enabled else { return }
        do {
            try service.register()
            NSLog("NewFileCreator: Registered as login item")
        } catch {
            NSLog("NewFileCreator: Login-item registration failed: \(error.localizedDescription)")
        }
    }

    private func showOnboardingIfExtensionDisabled() {
        guard ExtensionStatus.isEnabled() == false else { return }
        let controller = onboardingWindowController ?? OnboardingWindowController()
        onboardingWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(handleURL)
    }

    @IBAction func openExtensionSettings(_ sender: Any) {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard
            let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString)
        else {
            return
        }

        handleURL(url)
    }

    private func handleURL(_ url: URL) {
        do {
            let request = try FileCreationRequest(url: url)
            let fileURL = try FileCreator.createFile(for: request)
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } catch {
            NSLog("NewFileCreator: Failed to handle URL \(url.absoluteString): \(error)")
            showError(error.localizedDescription)
        }
    }
}

private enum AppURL {
    static let scheme = "newfilecreator"
    static let createHost = "create"
    static let directoryQueryItem = "directory"
    static let fileExtensionQueryItem = "ext"
}

private enum FileKind: String {
    case text = "txt"
    case markdown = "md"

    var defaultContent: String {
        switch self {
        case .text:
            return ""
        case .markdown:
            return "# New Document\n\n"
        }
    }
}

private struct FileCreationRequest {
    let directoryURL: URL
    let fileKind: FileKind

    init(url: URL) throws {
        guard url.scheme == AppURL.scheme, url.host == AppURL.createHost else {
            throw FileCreationError.unsupportedURL
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw FileCreationError.invalidURL
        }

        guard let directoryPath = components.queryItems?.first(where: { $0.name == AppURL.directoryQueryItem })?.value,
              !directoryPath.isEmpty else {
            throw FileCreationError.missingDirectory
        }

        guard let rawExtension = components.queryItems?.first(where: { $0.name == AppURL.fileExtensionQueryItem })?.value,
              let fileKind = FileKind(rawValue: rawExtension.lowercased()) else {
            throw FileCreationError.unsupportedFileType
        }

        self.directoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true).standardizedFileURL
        self.fileKind = fileKind
    }
}

private enum FileCreator {
    static func createFile(for request: FileCreationRequest) throws -> URL {
        try createFile(inDirectory: request.directoryURL, fileKind: request.fileKind)
    }

    static func createFile(inDirectory directory: URL, fileKind: FileKind) throws -> URL {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileCreationError.directoryDoesNotExist(directory)
        }

        return try createUniqueFile(
            in: directory,
            baseName: "Untitled",
            fileKind: fileKind
        )
    }

    private static func createUniqueFile(in directory: URL, baseName: String, fileKind: FileKind) throws -> URL {
        let fileManager = FileManager.default
        let data = Data(fileKind.defaultContent.utf8)

        for counter in 0..<10_000 {
            let fileName = counter == 0
                ? "\(baseName).\(fileKind.rawValue)"
                : "\(baseName) \(counter).\(fileKind.rawValue)"
            let fileURL = directory.appendingPathComponent(fileName)

            guard !fileManager.fileExists(atPath: fileURL.path) else {
                continue
            }

            do {
                try data.write(to: fileURL, options: .withoutOverwriting)
                return fileURL
            } catch {
                if fileManager.fileExists(atPath: fileURL.path) {
                    continue
                }
                throw error
            }
        }

        throw FileCreationError.noAvailableFileName(directory)
    }
}

private enum FileCreationError: LocalizedError {
    case invalidURL
    case unsupportedURL
    case missingDirectory
    case unsupportedFileType
    case directoryDoesNotExist(URL)
    case noAvailableFileName(URL)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The file creation request was not a valid URL."
        case .unsupportedURL:
            return "The file creation request was not meant for New File Creator."
        case .missingDirectory:
            return "The file creation request was missing a Finder folder."
        case .unsupportedFileType:
            return "The requested file type is not supported."
        case .directoryDoesNotExist(let url):
            return "The Finder folder does not exist:\n\n\(url.path)"
        case .noAvailableFileName(let url):
            return "Could not create a unique file name in:\n\n\(url.path)"
        }
    }
}

private func showError(_ message: String) {
    DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = "New File Creator"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
