#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILT_APP="$ROOT_DIR/build/NewFileCreator.app"
DEST_APP="/Applications/NewFileCreator.app"
EXTENSION="$DEST_APP/Contents/PlugIns/NewFileExtension.appex"
EXTENSION_ID="io.github.tjansn.NewFileCreator.NewFileExtension"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

if [[ ! -d "$BUILT_APP" ]]; then
  echo "Missing $BUILT_APP"
  echo "Run ./scripts/build.sh first."
  exit 1
fi

codesign --verify --deep --strict "$BUILT_APP"

# Install to a stable location. SMAppService.mainApp registers the app at its
# current path as a login item, so it must not run from build/.
echo "Installing to $DEST_APP"
rm -rf "$DEST_APP"
ditto "$BUILT_APP" "$DEST_APP"
codesign --verify --deep --strict "$DEST_APP"

# Register the bundle and the extension, then best-effort enable.
"$LSREGISTER" -f -R -trusted "$DEST_APP"
pluginkit -r "$EXTENSION" >/dev/null 2>&1 || true
pluginkit -a "$EXTENSION"
pluginkit -e use -i "$EXTENSION_ID" >/dev/null 2>&1 || true

# Launch the agent: this registers the login item and, if the extension is not yet
# enabled, shows the onboarding window that guides and live-detects the toggle.
open "$DEST_APP"

killall Finder >/dev/null 2>&1 || true

echo "Installed $DEST_APP"
echo "If the menu item does not appear, follow the onboarding window to enable the extension."
