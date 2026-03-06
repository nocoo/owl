#!/usr/bin/env bash
# scripts/package-dmg.sh — Create a distributable DMG from Owl.app
#
# Prerequisites:
#   Run build.sh first to create build/release/Owl.app
#
# Usage:
#   ./scripts/package-dmg.sh
#
# Output: build/release/Owl.dmg

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RELEASE_DIR="$PROJECT_DIR/build/release"
APP_BUNDLE="$RELEASE_DIR/Owl.app"
DMG_OUTPUT="$RELEASE_DIR/Owl.dmg"
DMG_STAGING="$PROJECT_DIR/build/dmg-staging"

# Get version from Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || echo "1.0.0")

if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "ERROR: $APP_BUNDLE not found."
    echo "       Run ./scripts/build.sh first."
    exit 1
fi

echo "==> Packaging Owl v$VERSION into DMG..."

# Clean staging area
rm -rf "$DMG_STAGING"
rm -f "$DMG_OUTPUT"
mkdir -p "$DMG_STAGING"

# Copy app to staging
echo "==> Copying Owl.app to staging..."
cp -R "$APP_BUNDLE" "$DMG_STAGING/"

# Create Applications symlink for drag-to-install
ln -s /Applications "$DMG_STAGING/Applications"

# Create DMG
echo "==> Creating DMG..."
hdiutil create \
    -volname "Owl" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_OUTPUT" > /dev/null 2>&1

# Cleanup staging
rm -rf "$DMG_STAGING"

DMG_SIZE=$(du -sh "$DMG_OUTPUT" | cut -f1)
echo ""
echo "==> DMG created!"
echo "    Output:  $DMG_OUTPUT"
echo "    Size:    $DMG_SIZE"
echo "    Version: $VERSION"
echo ""
echo "    To notarize: ./scripts/notarize.sh --dmg"
