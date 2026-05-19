#!/usr/bin/env bash
#
# build-dmg.sh — builds BreezeFan.app in Release mode and packages it as a .dmg
#
# Usage:
#   ./scripts/build-dmg.sh                              # basic — hdiutil
#   ./scripts/build-dmg.sh --pretty                     # branded — create-dmg
#                                                       #   (brew install create-dmg)
#   ./scripts/build-dmg.sh --pretty --regenerate-assets # rebuild bg + volicon first
#   ./scripts/build-dmg.sh --version 0.2.0              # custom version in filename
#
# Output:
#   dist/BreezeFan-<version>.dmg
#
# Pretty mode visual assets (auto-checked on launch):
#   - Resources/dmg-background.png  (1200×760 @2x; regen: scripts/generate-dmg-background.swift)
#   - Resources/dmg-volume.icns     (Finder sidebar icon; regen: scripts/build-dmg-volume-icon.sh)
#
# Notes on distribution:
#   - This builds with ad-hoc signing (CODE_SIGN_IDENTITY="-"). The .dmg works
#     for personal use but Gatekeeper will warn other users that the developer
#     "cannot be verified". They have to right-click → Open → Open Anyway.
#   - For real distribution: get an Apple Developer ID ($99/yr), set
#     CODE_SIGN_IDENTITY to your "Developer ID Application: <name>" cert, and
#     run notarytool after signing. Out of scope here.
#   - The helper inside the bundle is registered via SMAppService at first
#     launch (admin password prompt).

set -euo pipefail

# ─── Defaults ─────────────────────────────────────────────────────────────────

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="BreezeFan"
SCHEME="BreezeFan"
CONFIGURATION="Release"
VERSION="0.1.0"
PRETTY=false
REGEN_ASSETS=false
DIST_DIR="$PROJECT_DIR/dist"
BUILD_DIR="$PROJECT_DIR/.build/dmg"
BG_PNG="$PROJECT_DIR/Resources/dmg-background.png"
VOL_ICON="$PROJECT_DIR/Resources/dmg-volume.icns"

# ─── Parse args ───────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pretty)             PRETTY=true; shift ;;
    --regenerate-assets)  REGEN_ASSETS=true; shift ;;
    --version)            VERSION="$2"; shift 2 ;;
    --version=*)          VERSION="${1#*=}"; shift ;;
    --debug)              CONFIGURATION="Debug"; shift ;;
    -h|--help)
      head -n 30 "$0" | tail -n 28 | sed 's/^# //; s/^#$//'
      exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2 ;;
  esac
done

DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
STAGING_DIR="${BUILD_DIR}/staging"

# ─── Pre-flight checks ────────────────────────────────────────────────────────

echo "▸ Project: $PROJECT_DIR"
echo "▸ Version: $VERSION"
echo "▸ Config:  $CONFIGURATION"
echo "▸ Pretty:  $PRETTY"
echo

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "✗ xcodebuild not found. Install Xcode + run sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

if [[ ! -f "$PROJECT_DIR/BreezeFan.xcodeproj/project.pbxproj" ]]; then
  echo "▸ BreezeFan.xcodeproj not found — running xcodegen…"
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "✗ xcodegen not found. Install: brew install xcodegen" >&2
    exit 1
  fi
  ( cd "$PROJECT_DIR" && xcodegen generate )
fi

if $PRETTY && ! command -v create-dmg >/dev/null 2>&1; then
  echo "✗ --pretty requires create-dmg. Install: brew install create-dmg" >&2
  echo "  Or run without --pretty for the basic hdiutil version." >&2
  exit 1
fi

# ─── Regenerate assets (if requested) ─────────────────────────────────────────

if $REGEN_ASSETS; then
  echo "▸ Regenerating DMG visual assets…"
  swift "$PROJECT_DIR/scripts/generate-dmg-background.swift" "$BG_PNG" \
    || { echo "✗ generate-dmg-background.swift failed" >&2; exit 1; }
  bash "$PROJECT_DIR/scripts/build-dmg-volume-icon.sh" \
    || { echo "✗ build-dmg-volume-icon.sh failed" >&2; exit 1; }
fi

# ─── Pretty-mode asset pre-flight ─────────────────────────────────────────────

if $PRETTY; then
  if [[ ! -f "$BG_PNG" ]]; then
    echo "✗ background missing — re-run with --regenerate-assets" >&2
    echo "  Expected at: $BG_PNG" >&2
    exit 1
  fi
  BG_W=$(sips -g pixelWidth  "$BG_PNG" 2>/dev/null | awk '/pixelWidth/  {print $2}')
  BG_H=$(sips -g pixelHeight "$BG_PNG" 2>/dev/null | awk '/pixelHeight/ {print $2}')
  if [[ "$BG_W" != "1200" || "$BG_H" != "760" ]]; then
    echo "✗ background must be exactly 1200×760 (got ${BG_W}×${BG_H})" >&2
    echo "  Re-run with --regenerate-assets to fix." >&2
    exit 1
  fi
  if [[ ! -f "$VOL_ICON" ]]; then
    echo "✗ volume icon missing — re-run with --regenerate-assets" >&2
    echo "  Expected at: $VOL_ICON" >&2
    exit 1
  fi
fi

# ─── Clean & build ────────────────────────────────────────────────────────────

echo "▸ Cleaning previous build artifacts…"
rm -rf "$BUILD_DIR" "$DMG_PATH"
mkdir -p "$BUILD_DIR" "$STAGING_DIR" "$DIST_DIR"

echo "▸ Building $SCHEME ($CONFIGURATION) for macOS…"
xcodebuild \
  -project "$PROJECT_DIR/BreezeFan.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE="Manual" \
  build \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" \
  || true

BUILT_APP="$BUILD_DIR/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "✗ Build failed — $BUILT_APP not found" >&2
  exit 1
fi

echo "▸ Built app: $BUILT_APP"

# Verify helper is embedded
if [[ ! -f "$BUILT_APP/Contents/MacOS/Helpers/BreezeFanHelper" ]]; then
  echo "✗ Helper missing from app bundle — check project.yml postBuildScripts" >&2
  exit 1
fi
if [[ ! -f "$BUILT_APP/Contents/Library/LaunchDaemons/com.breezefan.helper.plist" ]]; then
  echo "✗ Helper plist missing from app bundle" >&2
  exit 1
fi

# ─── Re-sign with explicit entitlements + verify ──────────────────────────────
# This step guarantees:
#   1. The new disable-library-validation entitlement is sealed into the bundle
#      even when Xcode's incremental build cached an older signature.
#   2. All embedded frameworks (Sparkle, etc.) carry consistent --options=runtime
#      flags after the deep walk.
#   3. The helper gets its own entitlements (--deep alone won't apply per-binary
#      entitlements to nested executables).
#   4. codesign --verify --strict catches signature inconsistencies at build time
#      so we never ship a broken DMG again.
# See openspec change fix-login-item-library-validation-crash / design.md D3-D4.

# Signing order matters: innermost nested code must be signed BEFORE the
# outer bundle that seals them. We do three passes:
#   1. --deep on Sparkle.framework only → signs Sparkle + its XPCs/binaries
#      in the correct inside-out order, without touching the outer bundle.
#   2. Helper with its specific entitlements (no --deep needed, standalone binary).
#   3. Outer BreezeFan.app WITHOUT --deep (all nested code already signed).
#
# If we ran --deep on the full app THEN re-signed the helper, the outer seal
# would be broken. This order avoids that. See design.md D3.

echo "▸ Re-signing Sparkle.framework and its nested XPC services (inside-out)…"
codesign --force --deep \
  --sign "-" \
  --options=runtime \
  "$BUILT_APP/Contents/Frameworks/Sparkle.framework" \
  || { echo "✗ codesign Sparkle.framework failed" >&2; exit 1; }

echo "▸ Re-signing helper with its own entitlements…"
codesign --force \
  --sign "-" \
  --options=runtime \
  --entitlements "$PROJECT_DIR/Helper/BreezeFanHelper.entitlements" \
  "$BUILT_APP/Contents/MacOS/Helpers/BreezeFanHelper" \
  || { echo "✗ codesign helper failed" >&2; exit 1; }

echo "▸ Re-signing outer app bundle (all nested code already signed — no --deep)…"
codesign --force \
  --sign "-" \
  --options=runtime \
  --entitlements "$PROJECT_DIR/App/BreezeFan.entitlements" \
  "$BUILT_APP" \
  || { echo "✗ codesign main bundle failed" >&2; exit 1; }

echo "▸ Verifying signature (strict)…"
codesign --verify --deep --strict --verbose=2 "$BUILT_APP" \
  || { echo "✗ codesign verify failed" >&2; exit 1; }

echo "▸ Gatekeeper assessment (ad-hoc — expected to be 'rejected', informational only):"
spctl --assess --verbose=2 "$BUILT_APP" 2>&1 | head -3 || true
echo

# ─── Stage for DMG ────────────────────────────────────────────────────────────

echo "▸ Staging at ${STAGING_DIR}…"
cp -R "$BUILT_APP" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# ─── Build DMG ────────────────────────────────────────────────────────────────

if $PRETTY; then
  echo "▸ Building branded .dmg with create-dmg…"
  create-dmg \
    --volname "BreezeFan $VERSION" \
    --volicon "$VOL_ICON" \
    --background "$BG_PNG" \
    --window-pos 200 120 \
    --window-size 600 380 \
    --icon-size 128 \
    --icon "$APP_NAME.app" 150 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 450 190 \
    "$DMG_PATH" \
    "$STAGING_DIR/" \
    || { echo "✗ create-dmg failed" >&2; exit 1; }
else
  echo "▸ Building .dmg with hdiutil…"
  TEMP_DMG="$BUILD_DIR/temp.dmg"

  hdiutil create \
    -volname "BreezeFan $VERSION" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "$TEMP_DMG"

  hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

  rm -f "$TEMP_DMG"
fi

# ─── Final ───────────────────────────────────────────────────────────────────

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
DMG_SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')

echo
echo "✓ DMG created: $DMG_PATH ($DMG_SIZE)"
echo "  SHA256: $DMG_SHA256"
echo

# Gatekeeper assessment (informational — ad-hoc signing always rejected)
echo "▸ Gatekeeper assessment (ad-hoc — expected 'rejected'):"
spctl --assess --type open --context context:primary-signature -v "$DMG_PATH" 2>&1 \
  | head -2 \
  | sed 's/^/  /'
echo

echo "Test it:"
echo "  open '$DMG_PATH'"
echo
echo "Install:"
echo "  Drag BreezeFan.app to /Applications, then open it."
echo "  First launch will prompt for admin password to install the privileged helper."
