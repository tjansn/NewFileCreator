#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/Artwork/AppIcon.svg"
APPICONSET="$ROOT_DIR/NewFileCreator/NewFileCreator/Assets.xcassets/AppIcon.appiconset"

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "rsvg-convert is required. Install it with: brew install librsvg"
  exit 1
fi

mkdir -p "$APPICONSET"

for size in 16 32 64 128 256 512 1024; do
  rsvg-convert \
    --width "$size" \
    --height "$size" \
    --output "$APPICONSET/AppIcon-${size}.png" \
    "$SOURCE"
done

echo "Generated app icons in $APPICONSET"
