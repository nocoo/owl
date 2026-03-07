#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASE_DIR="$PROJECT_DIR/build/release"
APP_BUNDLE="$RELEASE_DIR/Owl.app"
DMG_PATH="$RELEASE_DIR/Owl.dmg"
CHANGELOG_PATH="$PROJECT_DIR/CHANGELOG.md"

RELEASE_NOTES=""
SKIP_BUILD=false
SKIP_PACKAGE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notes)
            RELEASE_NOTES="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-package)
            SKIP_PACKAGE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--notes path/to/file] [--skip-build] [--skip-package] [--dry-run]"
            exit 1
            ;;
    esac
done

VERSION=$(swift -e 'import Foundation; let text = try String(contentsOfFile: "Sources/OwlCore/OwlCore.swift"); let pattern = #"public static let version = \"([^\"]+)\""#; let regex = try NSRegularExpression(pattern: pattern); let range = NSRange(text.startIndex..., in: text); guard let match = regex.firstMatch(in: text, range: range), let versionRange = Range(match.range(at: 1), in: text) else { fputs("Unable to determine version\n", stderr); exit(1) }; print(String(text[versionRange]))' 2>/dev/null)
TAG="v$VERSION"
VERSIONED_DMG="$RELEASE_DIR/Owl-$TAG.dmg"

if [[ "$SKIP_BUILD" == false ]]; then
    "$SCRIPT_DIR/build.sh"
fi

if [[ "$SKIP_PACKAGE" == false ]]; then
    "$SCRIPT_DIR/package-dmg.sh"
fi

if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "ERROR: $APP_BUNDLE not found."
    exit 1
fi

if [[ ! -f "$DMG_PATH" ]]; then
    echo "ERROR: $DMG_PATH not found."
    exit 1
fi

cp "$DMG_PATH" "$VERSIONED_DMG"

TEMP_NOTES=false

if [[ -n "$RELEASE_NOTES" ]]; then
    NOTES_FILE="$RELEASE_NOTES"
else
    NOTES_FILE="$(mktemp)"
    TEMP_NOTES=true
    python3 - <<'PY' "$CHANGELOG_PATH" "$TAG" "$NOTES_FILE"
import sys
from pathlib import Path

changelog = Path(sys.argv[1]).read_text()
tag = sys.argv[2]
output = Path(sys.argv[3])
header = f"## {tag}"
if header not in changelog:
    raise SystemExit(f"Missing {header} in CHANGELOG.md")
section = changelog.split(header, 1)[1]
next_header = section.find("\n## ")
body = section[:next_header].strip() if next_header != -1 else section.strip()
output.write_text(body + "\n")
PY
fi

cleanup() {
    if [[ "$TEMP_NOTES" == true && -f "$NOTES_FILE" ]]; then
        rm -f "$NOTES_FILE"
    fi
}

trap cleanup EXIT

if [[ "$DRY_RUN" == true ]]; then
    echo "==> Dry run"
    echo "    Tag: $TAG"
    echo "    DMG: $VERSIONED_DMG"
    echo "    Notes: $NOTES_FILE"
    exit 0
fi

if gh release view "$TAG" >/dev/null 2>&1; then
    gh release upload "$TAG" "$VERSIONED_DMG" --clobber
else
    gh release create "$TAG" "$VERSIONED_DMG" --title "$TAG" --notes-file "$NOTES_FILE"
fi

echo "==> GitHub release ready"
echo "    Tag:   $TAG"
echo "    Asset: $VERSIONED_DMG"
