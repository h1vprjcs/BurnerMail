#!/bin/bash
# Builds BurnerMail (Release) and packages it as a distributable DMG.
#
# Usage:
#   ./package-dmg.sh                         # uses automatic signing from Xcode
#   ./package-dmg.sh --team YOUR_TEAM_ID     # pass your Apple Developer Team ID
#
# Run from the folder containing BurnerMail.xcodeproj

set -e

APP_NAME="BurnerMail"
VERSION="1.0"
DMG_NAME="${APP_NAME}-${VERSION}"
PROJECT="BurnerMail.xcodeproj"
SCHEME="BurnerMail"
BUILD_DIR="build"
DIST_DIR="dist"
TEAM_ID=""

# Parse optional --team argument
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --team) TEAM_ID="$2"; shift ;;
  esac
  shift
done

# Build extra args for xcodebuild if team ID supplied
TEAM_ARGS=""
if [ -n "$TEAM_ID" ]; then
  TEAM_ARGS="DEVELOPMENT_TEAM=$TEAM_ID"
  echo ">>> Using Team ID: $TEAM_ID"
fi

echo ">>> Building ${APP_NAME} Release..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_STYLE=Automatic \
  $TEAM_ARGS \
  clean build 2>&1 | grep -E "error:|Build succeeded|Build FAILED|warning: " | grep -v "warning:" || true

# Locate the compiled .app
APP_PATH=$(find "$BUILD_DIR" -name "${APP_NAME}.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
  echo ""
  echo "ERROR: ${APP_NAME}.app not found after build."
  echo "  1. Open BurnerMail.xcodeproj in Xcode"
  echo "  2. Go to Signing & Capabilities, select your Team"
  echo "  3. Press Cmd+B to confirm it builds, then re-run this script"
  echo "     with: ./package-dmg.sh --team YOUR_TEAM_ID"
  exit 1
fi

echo ">>> App built at: $APP_PATH"

# Strip quarantine attributes and apply ad-hoc signature.
# Without this, unsigned apps on macOS 13+ show a hard block with no
# "Open Anyway" button. Ad-hoc signing (-) requires no Apple Developer account
# but gives Gatekeeper enough info to surface the bypass option.
echo ">>> Applying ad-hoc signature..."
xattr -cr "$APP_PATH"
codesign --force --deep --sign - "$APP_PATH"
echo ">>> Ad-hoc signature applied."

echo ">>> Packaging as DMG..."

mkdir -p "$DIST_DIR"
DMG_TEMP="${DIST_DIR}/${DMG_NAME}-temp.dmg"
DMG_FINAL="${DIST_DIR}/${DMG_NAME}.dmg"
rm -f "$DMG_TEMP" "$DMG_FINAL"

# Create writable DMG, copy app + Applications shortcut
hdiutil create -size 80m -fs HFS+ -volname "$APP_NAME" "$DMG_TEMP" -quiet
# Attach without -quiet so the mount path is printed, then extract it reliably
MOUNT_POINT=$(hdiutil attach "$DMG_TEMP" -noverify -noautoopen | grep -E '^/dev/' | tail -1 | awk '{print $NF}')
echo ">>> Mounted at: $MOUNT_POINT"
cp -R "$APP_PATH" "$MOUNT_POINT/"
ln -s /Applications "$MOUNT_POINT/Applications"
hdiutil detach "$MOUNT_POINT" -quiet

# Compress to final read-only DMG
hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_FINAL" -quiet
rm -f "$DMG_TEMP"

echo ""
echo "=========================================="
echo "  DMG ready: ${DIST_DIR}/${DMG_NAME}.dmg"
echo "=========================================="
echo ""
echo "To release on GitHub:"
echo "  1. Go to your repo > Releases > Draft a new release"
echo "  2. Tag: v${VERSION}"
echo "  3. Attach: ${DIST_DIR}/${DMG_NAME}.dmg"
echo "  4. Publish"
echo ""
echo "NOTE: First-time users may see a Gatekeeper warning."
echo "      Tell them: right-click the app > Open (only needed once)."
echo ""
echo "To remove the warning entirely, notarize with:"
echo "  xcrun notarytool submit ${DIST_DIR}/${DMG_NAME}.dmg \\"
echo "    --apple-id YOUR_APPLE_ID \\"
echo "    --team-id YOUR_TEAM_ID \\"
echo "    --password YOUR_APP_SPECIFIC_PASSWORD \\"
echo "    --wait"
echo "  xcrun stapler staple ${DIST_DIR}/${DMG_NAME}.dmg"
