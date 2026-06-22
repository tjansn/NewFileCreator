import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    override init() {
        super.init()

        let finderSync = FIFinderSyncController.default()
        finderSync.directoryURLs = monitoredDirectoryURLs()
        NSLog("NewFileCreator: Monitoring Finder directories: \(finderSync.directoryURLs.map(\.path).sorted().joined(separator: ", "))")

        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL {
                FIFinderSyncController.default().directoryURLs.insert(volumeURL)
            }
        }
    }

    override var toolbarItemName: String {
        "New File"
    }

    override var toolbarItemToolTip: String {
        "Create a new file in the current Finder folder"
    }

    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "New file")
            ?? NSImage(named: NSImage.addTemplateName)
            ?? NSImage(size: NSSize(width: 16, height: 16))
    }

    // MARK: - Context Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        NSLog("NewFileCreator: Building Finder menu for kind \(menuKind.rawValue)")

        let menu = NSMenu(title: "")
        menu.autoenablesItems = false

        // A single "New File" parent item with a submenu of file types matches
        // the native Finder pattern (e.g. "New Folder with Selection", Services).
        let parent = NSMenuItem(title: "New File", action: nil, keyEquivalent: "")
        applyNativeMenuIcon(parent, symbolName: "doc.badge.plus", accessibilityDescription: "New file")

        let submenu = NSMenu(title: "")
        submenu.autoenablesItems = false
        submenu.addItem(makeMenuItem(
            title: "Text File",
            symbolName: "doc.text",
            action: #selector(createTextFile(_:)),
            accessibilityDescription: "Text file"
        ))
        submenu.addItem(makeMenuItem(
            title: "Markdown File",
            symbolName: "doc.richtext",
            action: #selector(createMarkdownFile(_:)),
            accessibilityDescription: "Markdown file"
        ))

        parent.submenu = submenu
        menu.addItem(parent)

        return menu
    }

    // MARK: - Actions

    @objc func createTextFile(_ sender: AnyObject?) {
        createFile(kind: .text)
    }

    @objc func createMarkdownFile(_ sender: AnyObject?) {
        createFile(kind: .markdown)
    }

    private func createFile(kind: FileKind) {
        guard let targetURL = targetDirectoryURL() else {
            showError("Could not determine the Finder folder to create the file in.")
            return
        }

        guard let url = FileCreationRequest(directoryURL: targetURL, fileKind: kind).url else {
            showError("Could not build the file creation request.")
            return
        }

        NSLog("NewFileCreator: Requesting \(kind.rawValue) file creation in \(targetURL.path)")

        if !NSWorkspace.shared.open(url) {
            showError("Could not open New File Creator to create the file.")
        }
    }

    private func monitoredDirectoryURLs() -> Set<URL> {
        let fileManager = FileManager.default
        var urls: Set<URL> = [
            URL(fileURLWithPath: "/", isDirectory: true),
            URL(fileURLWithPath: "/Volumes", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser
        ]

        let searchPaths: [FileManager.SearchPathDirectory] = [
            .desktopDirectory,
            .documentDirectory,
            .downloadsDirectory,
            .applicationDirectory
        ]

        for searchPath in searchPaths {
            urls.formUnion(fileManager.urls(for: searchPath, in: .userDomainMask))
        }

        if let mountedVolumes = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: []) {
            urls.formUnion(mountedVolumes)
        }

        return Set(urls.filter { url in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        })
    }

    private func targetDirectoryURL() -> URL? {
        let controller = FIFinderSyncController.default()

        if let targetedURL = controller.targetedURL() {
            return directoryURL(for: targetedURL)
        }

        if let selectedURL = controller.selectedItemURLs()?.first {
            return directoryURL(for: selectedURL)
        }

        return nil
    }

    private func directoryURL(for url: URL) -> URL {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return url
        }

        return url.deletingLastPathComponent()
    }

    private func makeMenuItem(
        title: String,
        symbolName: String,
        action: Selector,
        accessibilityDescription: String
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        applyNativeMenuIcon(item, symbolName: symbolName, accessibilityDescription: accessibilityDescription)
        return item
    }

    /// Applies a leading icon only where it looks native for the running OS.
    ///
    /// - macOS 14/15: native Finder context menus have no leading icons, so adding
    ///   one would stand out. We leave `image` nil.
    /// - macOS 26+: AppKit shows menu icons, so we add an SF Symbol sized to match
    ///   Apple's glyph metrics.
    /// - macOS 27+: symbol images are hidden by default; we opt this item back in.
    ///
    /// Finder Sync menus don't reliably tint template images for the current
    /// appearance — a known bug where symbols render black (no contrast) in dark
    /// mode. So instead of relying on `isTemplate`, we bake the correct color into
    /// the image based on the live system appearance.
    private func applyNativeMenuIcon(
        _ item: NSMenuItem,
        symbolName: String,
        accessibilityDescription: String
    ) {
        guard #available(macOS 26, *) else {
            item.image = nil
            return
        }

        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular, scale: .medium)
        if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(configuration) {
            let tint: NSColor = isSystemInDarkMode() ? .white : .black
            item.image = symbol.tintedForMenu(with: tint)
        }

        // `preferredImageVisibility` is new in macOS 27; set it dynamically so this
        // still builds against older SDKs.
        let visibilityKey = "preferredImageVisibility"
        if item.responds(to: NSSelectorFromString("set\(visibilityKey.prefix(1).uppercased())\(visibilityKey.dropFirst()):")) {
            item.setValue(1 /* .visible */, forKey: visibilityKey)
        }
    }

    /// Reads the system-wide appearance directly. We avoid `effectiveAppearance`
    /// because the Finder Sync host process can report a stale (light) appearance,
    /// which is the root cause of the black-icon-in-dark-mode bug.
    private func isSystemInDarkMode() -> Bool {
        if let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") {
            return style.lowercased().contains("dark")
        }
        return false
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
}

private extension NSImage {
    /// Returns a copy with `color` baked into the opaque pixels, marked as a
    /// non-template image so AppKit won't re-tint it against a stale appearance.
    func tintedForMenu(with color: NSColor) -> NSImage {
        let tinted = NSImage(size: size)
        tinted.lockFocus()
        draw(in: NSRect(origin: .zero, size: size))
        color.set()
        NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
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
}

private struct FileCreationRequest {
    let directoryURL: URL
    let fileKind: FileKind

    var url: URL? {
        var components = URLComponents()
        components.scheme = AppURL.scheme
        components.host = AppURL.createHost
        components.queryItems = [
            URLQueryItem(name: AppURL.directoryQueryItem, value: directoryURL.path),
            URLQueryItem(name: AppURL.fileExtensionQueryItem, value: fileKind.rawValue)
        ]
        return components.url
    }
}
