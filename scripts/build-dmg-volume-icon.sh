#!/usr/bin/env bash
#
# build-dmg-volume-icon.sh — derives Resources/dmg-volume.icns from AppIcon.icns
#
# Output:  Resources/dmg-volume.icns
# Run:     ./scripts/build-dmg-volume-icon.sh
#
# create-dmg's --volicon expects a multi-resolution .icns file. The simplest
# good result is to reuse AppIcon.icns as the volume icon — distinctive in
# the Finder sidebar, and zero divergence between "the app's icon" and
# "the installer disk's icon".

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_ICON="$PROJECT_DIR/Resources/AppIcon.icns"
OUT_ICON="$PROJECT_DIR/Resources/dmg-volume.icns"

if [[ ! -f "$APP_ICON" ]]; then
  echo "✗ $APP_ICON not found — run ./scripts/build-icon.sh first" >&2
  exit 1
fi

# Round-trip through an iconset to validate the source + produce a clean
# .icns with the standard 10-slot resolution ladder.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ICONSET_DIR="$TMP_DIR/dmg-volume.iconset"

echo "▸ Extracting AppIcon.icns → iconset…"
iconutil --convert iconset \
  --output "$ICONSET_DIR" \
  "$APP_ICON"

# Sanity: confirm the iconset has the expected resolutions.
expected_files=(
  "icon_16x16.png"      "icon_16x16@2x.png"
  "icon_32x32.png"      "icon_32x32@2x.png"
  "icon_128x128.png"    "icon_128x128@2x.png"
  "icon_256x256.png"    "icon_256x256@2x.png"
  "icon_512x512.png"    "icon_512x512@2x.png"
)
for f in "${expected_files[@]}"; do
  if [[ ! -f "$ICONSET_DIR/$f" ]]; then
    echo "✗ AppIcon.icns is missing $f — regenerate via scripts/build-icon.sh" >&2
    exit 1
  fi
done

echo "▸ Repackaging iconset → $OUT_ICON"
iconutil --convert icns \
  --output "$OUT_ICON" \
  "$ICONSET_DIR"

SIZE=$(stat -f %z "$OUT_ICON" 2>/dev/null || stat -c %s "$OUT_ICON")
echo "✓ Wrote $OUT_ICON ($SIZE bytes)"
