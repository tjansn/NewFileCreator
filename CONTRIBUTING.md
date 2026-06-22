# Contributing

Thanks for your interest in improving New File Creator.

## Requirements

- macOS 14.0 or newer
- Xcode 15 or newer

## Development

```bash
make build          # build to build/NewFileCreator.app (ad-hoc signed)
make install-local  # install to /Applications, register the extension, restart Finder
```

When you change the containing agent, quit the running instance before reinstalling
so the new binary is loaded:

```bash
pkill -f "/Applications/NewFileCreator.app/Contents/MacOS/NewFileCreator"
make install-local
```

## Architecture

- The **Finder Sync extension** (`NewFileExtension/FinderSync.swift`) is sandboxed.
  It only builds the context menu and resolves the target folder — it does not write
  files.
- The **containing app** (`NewFileCreator/`) is a headless background agent. It
  handles the `newfilecreator://` URL, hosts the global shortcuts, and performs the
  actual file writes.

Keep the extension thin; do filesystem work in the agent.

## Pull requests

- Match the existing Swift style.
- Update `CHANGELOG.md` under **Unreleased** for user-facing changes.
- For larger changes, please open an issue to discuss first.
