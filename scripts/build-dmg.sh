#!/usr/bin/env bash
#
# build-dmg.sh — builds FanControl.app in Release mode and packages it as a .dmg
#
# Usage:
#   ./scripts/build-dmg.sh                  # default — uses hdiutil
#   ./scripts/build-dmg.sh --pretty         # uses create-dmg (brew install create-dmg)
#   ./scripts/build-dmg.sh --version 0.2.0  # custom version in filename
#
# Output:
#   dist/FanControl-<version>.dmg
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
APP_NAME="FanControl"
SCHEME="FanControl"
CONFIGURATION="Release"
VERSION="0.1.0"
PRETTY=false
DIST_DIR="$PROJECT_DIR/dist"
BUILD_DIR="$PROJECT_DIR/.build/dmg"

# ─── Parse args ───────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pretty)         PRETTY=true; shift ;;
    --version)        VERSION="$2"; shift 2 ;;
    --version=*)      VERSION="${1#*=}"; shift ;;
    --debug)          CONFIGURATION="Debug"; shift ;;
    -h|--help)
      head -n 25 "$0" | tail -n 23 | sed 's/^# //; s/^#$//'
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

if [[ ! -f "$PROJECT_DIR/FanControl.xcodeproj/project.pbxproj" ]]; then
  echo "▸ FanControl.xcodeproj not found — running xcodegen…"
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

# ─── Clean & build ────────────────────────────────────────────────────────────

echo "▸ Cleaning previous build artifacts…"
rm -rf "$BUILD_DIR" "$DMG_PATH"
mkdir -p "$BUILD_DIR" "$STAGING_DIR" "$DIST_DIR"

echo "▸ Building $SCHEME ($CONFIGURATION) for macOS…"
xcodebuild \
  -project "$PROJECT_DIR/FanControl.xcodeproj" \
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
if [[ ! -f "$BUILT_APP/Contents/MacOS/Helpers/FanControlHelper" ]]; then
  echo "✗ Helper missing from app bundle — check project.yml postBuildScripts" >&2
  exit 1
fi
if [[ ! -f "$BUILT_APP/Contents/Library/LaunchDaemons/com.fancontrol.helper.plist" ]]; then
  echo "✗ Helper plist missing from app bundle" >&2
  exit 1
fi

# ─── Stage for DMG ────────────────────────────────────────────────────────────

echo "▸ Staging at $STAGING_DIR…"
cp -R "$BUILT_APP" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# ─── Build DMG ────────────────────────────────────────────────────────────────

if $PRETTY; then
  echo "▸ Building .dmg with create-dmg…"
  create-dmg \
    --volname "FanControl $VERSION" \
    --window-pos 200 120 \
    --window-size 600 380 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 150 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 450 190 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$STAGING_DIR/" \
    || { echo "✗ create-dmg failed" >&2; exit 1; }
else
  echo "▸ Building .dmg with hdiutil…"
  TEMP_DMG="$BUILD_DIR/temp.dmg"

  hdiutil create \
    -volname "FanControl $VERSION" \
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
echo
echo "✓ DMG created: $DMG_PATH ($DMG_SIZE)"
echo
echo "Test it:"
echo "  open '$DMG_PATH'"
echo
echo "Install:"
echo "  Drag FanControl.app to /Applications, then open it."
echo "  First launch will prompt for admin password to install the privileged helper."
