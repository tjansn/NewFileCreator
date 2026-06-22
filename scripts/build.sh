#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/NewFileCreator/NewFileCreator.xcodeproj"
SCHEME="NewFileCreator"
CONFIGURATION="Release"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP="$ROOT_DIR/build/NewFileCreator.app"
PRODUCT_APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/NewFileCreator.app"

xcodebuild \
  -quiet \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  build

mkdir -p "$ROOT_DIR/build"
ditto "$PRODUCT_APP" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Built $APP"
