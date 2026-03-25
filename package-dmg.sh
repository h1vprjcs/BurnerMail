#!/bin/bash
# Builds BurnerMail (Release) and packages it as a distributable DMG.
# Optionally notarizes and staples the DMG so macOS Gatekeeper lets users open it.
#
# Usage:
#   ./package-dmg.sh                                     # build + package only (unsigned/unnotarized)
#   ./package-dmg.sh --team YOUR_TEAM_ID                 # specify Team ID for signing
#   ./package-dmg.sh --notarize \
#     --team YOUR_TEAM_ID \
#     --apple-id you@example.com \
#     --password xxxx-xxxx-xxxx-xxxx                     # sign + notarize + staple
#
# NOTE: macOS 15 (Sequoia) and later enforce Gatekeeper for ALL apps downloaded
# from the internet. Without notarization users see:
#   "BurnerMail.app can't be opened."  (no "Open Anyway" option)
# Always notarize before releasing a public build.
#
# Run from the folder containing BurnerMail.xcodeproj.

set -e

APP_NAME="BurnerMail"
VERSION="1.0"
DMG_NAME="${APP_NAME}-${VERSION}"
PROJECT="BurnerMail.xcodeproj"
SCHEME="BurnerMail"
BUILD_DIR="build"
DIST_DIR="dist"

TEAM_ID=""
APPLE_ID=""
APP_PASSWORD=""
NOTARIZE=false

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --team)     TEAM_ID="$2";       shift ;;
    --apple-id) APPLE_ID="$2";      shift ;;
    --password) APP_PASSWORD="$2";  shift ;;
    --notarize) NOTARIZE=true       ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
  shift
done

# Validate notarization args
if $NOTARIZE; then
  if [ -z "$TEAM_ID" ] || [ -z "$APPLE_ID" ] || [ -z "$APP_PASSWORD" ]; then
    echo "ERROR: --notarize requires --team, --apple-id, and --password."
    echo "  Example:"
    echo "    ./package-dmg.sh --notarize \\"
    echo "      --team ABCDE12345 \\"
    echo "      --apple-id you@example.com \\"
    echo "      --password xxxx-xxxx-xxxx-xxxx"
    echo ""
    echo "  Generate an app-specific password at: https://appleid.apple.com"
    exit 1
  fi
fi

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
echo ">>> Packaging as DMG..."

mkdir -p "$DIST_DIR"
DMG_TEMP="${DIST_DIR}/${DMG_NAME}-temp.dmg"
DMG_FINAL="${DIST_DIR}/${DMG_NAME}.dmg"
rm -f "$DMG_TEMP" "$DMG_FINAL"

# Create writable DMG, copy app + Applications shortcut
hdiutil create -size 80m -fs HFS+ -volname "$APP_NAME" "$DMG_TEMP" -quiet
MOUNT_POINT=$(hdiutil attach "$DMG_TEMP" -quiet | awk 'END{print $NF}')
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

# ── Notarization ────────────────────────────────────────────────────────────
if $NOTARIZE; then
  echo ""
  echo ">>> Submitting to Apple Notary Service (this may take a few minutes)..."
  xcrun notarytool submit "$DMG_FINAL" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait

  echo ">>> Stapling notarization ticket to DMG..."
  xcrun stapler staple "$DMG_FINAL"

  echo ""
  echo "=========================================="
  echo "  Notarized DMG: ${DIST_DIR}/${DMG_NAME}.dmg"
  echo "  Users can now open the app without any Gatekeeper warning."
  echo "=========================================="
else
  echo ""
  echo "WARNING: This DMG is NOT notarized."
  echo "  macOS 15 (Sequoia) and later will block users from opening the app"
  echo "  with no option to override. Always notarize public releases:"
  echo ""
  echo "    ./package-dmg.sh --notarize \\"
  echo "      --team YOUR_TEAM_ID \\"
  echo "      --apple-id you@example.com \\"
  echo "      --password YOUR_APP_SPECIFIC_PASSWORD"
  echo ""
  echo "  Generate an app-specific password at: https://appleid.apple.com"
fi

echo ""
echo "To release on GitHub:"
echo "  1. Go to your repo > Releases > Draft a new release"
echo "  2. Tag: v${VERSION}"
echo "  3. Attach: ${DIST_DIR}/${DMG_NAME}.dmg"
echo "  4. Publish"
echo ""
