#!/usr/bin/env bash
# Generates Resources/AppIcon.icns from the SwiftUI fan symbol design.
# Output: Resources/AppIcon.icns (referenced by project.yml)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RES_DIR="$PROJECT_DIR/Resources"
TMP_DIR="$PROJECT_DIR/.build/icon"
ICONSET="$TMP_DIR/AppIcon.iconset"

mkdir -p "$RES_DIR" "$TMP_DIR" "$ICONSET"

echo "▸ Generating 1024×1024 master PNG via SwiftUI ImageRenderer…"
swift "$PROJECT_DIR/scripts/generate-icon.swift" "$TMP_DIR/icon-1024.png"

echo "▸ Resizing to all required iconset sizes…"
# macOS .iconset requires these exact filenames
declare -a SIZES=(
  "16:icon_16x16.png"
  "32:icon_16x16@2x.png"
  "32:icon_32x32.png"
  "64:icon_32x32@2x.png"
  "128:icon_128x128.png"
  "256:icon_128x128@2x.png"
  "256:icon_256x256.png"
  "512:icon_256x256@2x.png"
  "512:icon_512x512.png"
  "1024:icon_512x512@2x.png"
)
for entry in "${SIZES[@]}"; do
  size="${entry%%:*}"
  name="${entry#*:}"
  sips -z "$size" "$size" "$TMP_DIR/icon-1024.png" --out "$ICONSET/$name" >/dev/null
done

echo "▸ Compiling .icns…"
iconutil -c icns "$ICONSET" -o "$RES_DIR/AppIcon.icns"

# Copy a versionless 512px PNG too (useful for README screenshots / github og:image)
cp "$TMP_DIR/icon-1024.png" "$RES_DIR/AppIcon-1024.png"

echo "✓ Wrote $RES_DIR/AppIcon.icns"
echo "✓ Wrote $RES_DIR/AppIcon-1024.png (for previews)"
ls -lh "$RES_DIR/AppIcon.icns"
