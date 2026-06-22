# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- **Background agent.** The containing app is a headless `LSUIElement` agent
  registered as a login item via `SMAppService`. It stays resident, so creating a
  file no longer pays a cold app-launch cost.
- **Global shortcuts** that create a file in the folder Finder is currently showing,
  including the Desktop (which the Finder context menu cannot reach):
  - `⌃⌥⌘N` — new text file
  - `⌃⌥⌘M` — new Markdown file
- **Configurable shortcuts.** A Settings window (open by double-clicking the app)
  lets you rebind, disable, or reset each shortcut. Changes apply immediately.
- **Onboarding window.** When the Finder extension is not yet enabled, the app shows
  an OS-version-aware window that deep-links to the correct Settings pane, detects
  when the extension is turned on, and restarts Finder automatically.

### Changed
- The Finder context menu now uses a single **New File** item with a file-type
  submenu, matching native Finder patterns.
- Menu icons render only on macOS versions where native context menus show them and
  tint correctly in dark mode.
- `make install-local` now installs to `/Applications` (a stable path is required for
  the login item) and launches the agent to drive onboarding.

## [1.0]

### Added
- Initial Finder Sync extension adding **New File** and **New Markdown File** to the
  Finder context menu, with automatic unique naming (e.g. `Untitled 1.txt`).
