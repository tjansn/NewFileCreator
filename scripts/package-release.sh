#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/NewFileCreator/NewFileCreator.xcodeproj"
SCHEME="NewFileCreator"
CONFIGURATION="Release"
DERIVED_DATA="$ROOT_DIR/build/ReleaseDerivedData"
RELEASE_DIR="$ROOT_DIR/release"
PRODUCT_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/NewFileCreator.app"
APP="$RELEASE_DIR/NewFileCreator.app"
ZIP="$RELEASE_DIR/NewFileCreator.zip"
NOTARIZED_ZIP="$RELEASE_DIR/NewFileCreator-notarized.zip"

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "SIGN_IDENTITY is required."
  echo "Example: SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./scripts/package-release.sh"
  exit 1
fi

if ! security find-identity -p codesigning -v | grep -F "$SIGN_IDENTITY" >/dev/null; then
  echo "Could not find code signing identity:"
  echo "  $SIGN_IDENTITY"
  echo
  echo "Available identities:"
  security find-identity -p codesigning -v || true
  exit 1
fi

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

xcodebuild \
  -quiet \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build

ditto "$PRODUCT_APP" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose "$APP"

ditto -c -k --keepParent "$APP" "$ZIP"
echo "Created $ZIP"

if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "Skipping notarization because NOTARY_PROFILE is not set."
  echo "Create one with: xcrun notarytool store-credentials <profile-name>"
  exit 0
fi

xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

rm -f "$NOTARIZED_ZIP"
ditto -c -k --keepParent "$APP" "$NOTARIZED_ZIP"
echo "Created $NOTARIZED_ZIP"
