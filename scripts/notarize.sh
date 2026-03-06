#!/usr/bin/env bash
# scripts/notarize.sh — Notarize Owl.app or Owl.dmg with Apple
#
# Prerequisites:
#   1. App must be code-signed with Developer ID (run build.sh --sign first)
#   2. Store credentials: xcrun notarytool store-credentials "owl-notarize"
#      (will prompt for Apple ID, Team ID, and app-specific password)
#
# Usage:
#   ./scripts/notarize.sh                           # notarize Owl.app
#   ./scripts/notarize.sh --dmg                     # notarize Owl.dmg
#   ./scripts/notarize.sh --profile my-profile      # use custom keychain profile
#
# Environment variables (alternative to --profile):
#   APPLE_ID      — Apple ID email
#   TEAM_ID       — Developer Team ID
#   APP_PASSWORD  — App-specific password

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RELEASE_DIR="$PROJECT_DIR/build/release"
NOTARIZE_DMG=false
KEYCHAIN_PROFILE="owl-notarize"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dmg)
            NOTARIZE_DMG=true
            shift
            ;;
        --profile)
            KEYCHAIN_PROFILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dmg] [--profile profile-name]"
            exit 1
            ;;
    esac
done

# Determine what to notarize
if [[ "$NOTARIZE_DMG" == true ]]; then
    TARGET="$RELEASE_DIR/Owl.dmg"
    STAPLE_TARGET="$TARGET"
else
    TARGET="$RELEASE_DIR/Owl.app"
    STAPLE_TARGET="$TARGET"
fi

if [[ ! -e "$TARGET" ]]; then
    echo "ERROR: $TARGET not found. Run build.sh first."
    exit 1
fi

# Verify code signature before notarizing
echo "==> Verifying code signature..."
if [[ "$NOTARIZE_DMG" == false ]]; then
    codesign --verify --deep --strict "$TARGET" 2>&1
    echo "    Signature valid."
fi

# Create zip for submission (if notarizing .app)
SUBMIT_FILE="$TARGET"
if [[ "$NOTARIZE_DMG" == false ]]; then
    echo "==> Creating zip for submission..."
    ZIP_FILE="$RELEASE_DIR/Owl.zip"
    ditto -c -k --keepParent "$TARGET" "$ZIP_FILE"
    SUBMIT_FILE="$ZIP_FILE"
    echo "    Created: $ZIP_FILE"
fi

# Build notarytool auth flags
AUTH_FLAGS=()
if [[ -n "${APPLE_ID:-}" && -n "${TEAM_ID:-}" && -n "${APP_PASSWORD:-}" ]]; then
    echo "==> Using environment variable credentials"
    AUTH_FLAGS=(--apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$APP_PASSWORD")
else
    echo "==> Using keychain profile: $KEYCHAIN_PROFILE"
    AUTH_FLAGS=(--keychain-profile "$KEYCHAIN_PROFILE")
fi

# Submit for notarization
echo "==> Submitting for notarization..."
xcrun notarytool submit "$SUBMIT_FILE" \
    "${AUTH_FLAGS[@]}" \
    --wait \
    --timeout 30m

# Staple the notarization ticket
echo "==> Stapling notarization ticket..."
xcrun stapler staple "$STAPLE_TARGET"

# Verify
echo "==> Verifying notarization..."
spctl --assess --type execute --verbose "$STAPLE_TARGET" 2>&1

# Cleanup zip if we created one
if [[ "$NOTARIZE_DMG" == false && -f "$ZIP_FILE" ]]; then
    rm "$ZIP_FILE"
    echo "    Cleaned up temporary zip."
fi

echo ""
echo "==> Notarization complete!"
echo "    $STAPLE_TARGET is ready for distribution."
