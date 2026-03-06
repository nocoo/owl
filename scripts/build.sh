#!/usr/bin/env bash
# scripts/build.sh — Build Owl.app bundle from SPM release binary
#
# Usage:
#   ./scripts/build.sh                    # unsigned build
#   ./scripts/build.sh --sign "Developer ID Application: Name (TEAMID)"
#
# Output: build/release/Owl.app

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SIGN_IDENTITY=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sign)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--sign \"Developer ID Application: Name (TEAMID)\"]"
            exit 1
            ;;
    esac
done

BUILD_DIR="$PROJECT_DIR/build"
RELEASE_DIR="$BUILD_DIR/release"
APP_BUNDLE="$RELEASE_DIR/Owl.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Cleaning previous build..."
rm -rf "$APP_BUNDLE"

echo "==> Building release binary with SPM..."
swift build -c release --package-path "$PROJECT_DIR" 2>&1

# Find the built executable
EXECUTABLE="$PROJECT_DIR/.build/release/Owl"
if [[ ! -f "$EXECUTABLE" ]]; then
    echo "ERROR: Built executable not found at $EXECUTABLE"
    exit 1
fi

echo "==> Creating app bundle structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "==> Copying executable..."
cp "$EXECUTABLE" "$MACOS_DIR/Owl"

echo "==> Copying Info.plist..."
cp "$PROJECT_DIR/Sources/Owl/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

# Generate .icns from owl.png if available
ICON_SOURCE="$PROJECT_DIR/owl.png"
if [[ -f "$ICON_SOURCE" ]]; then
    echo "==> Generating app icon from owl.png..."
    ICONSET_DIR="$BUILD_DIR/Owl.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"

    # Generate all required icon sizes
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png"      > /dev/null 2>&1
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png"   > /dev/null 2>&1
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png"      > /dev/null 2>&1
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png"   > /dev/null 2>&1
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png"    > /dev/null 2>&1
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null 2>&1
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png"    > /dev/null 2>&1
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null 2>&1
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png"    > /dev/null 2>&1
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null 2>&1

    iconutil -c icns -o "$RESOURCES_DIR/AppIcon.icns" "$ICONSET_DIR"
    rm -rf "$ICONSET_DIR"

    # Inject CFBundleIconFile into Info.plist if not already present
    if ! /usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$CONTENTS_DIR/Info.plist" > /dev/null 2>&1; then
        /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$CONTENTS_DIR/Info.plist"
    fi
    echo "    Icon generated: $RESOURCES_DIR/AppIcon.icns"
else
    echo "    WARN: owl.png not found, skipping icon generation"
fi

# Code sign if identity provided
if [[ -n "$SIGN_IDENTITY" ]]; then
    ENTITLEMENTS="$PROJECT_DIR/Sources/Owl/Resources/Owl.entitlements"

    echo "==> Code signing with Hardened Runtime..."
    codesign --force --options runtime \
        --sign "$SIGN_IDENTITY" \
        --entitlements "$ENTITLEMENTS" \
        --timestamp \
        "$APP_BUNDLE"

    echo "==> Verifying signature..."
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" 2>&1
    echo "    Signature valid."
else
    echo "==> Skipping code signing (no --sign identity provided)"
    echo "    To sign: $0 --sign \"Developer ID Application: Name (TEAMID)\""
fi

# Print result
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo ""
echo "==> Build complete!"
echo "    Output: $APP_BUNDLE"
echo "    Size:   $APP_SIZE"
