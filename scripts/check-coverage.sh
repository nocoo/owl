#!/bin/bash
set -e

THRESHOLD=${1:-90}

find_codecov_json() {
    local candidate
    for candidate in \
        ".build/arm64-apple-macosx/debug/codecov/Owl.json" \
        ".build/out/Products/Debug/codecov/Owl.json"
    do
        if [ -f "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

CODECOV_JSON="$(find_codecov_json)" || {
    echo "✗ Coverage data not found. Run tests with --enable-code-coverage first."
    echo "  Checked: .build/arm64-apple-macosx/debug/codecov/Owl.json"
    echo "           .build/out/Products/Debug/codecov/Owl.json"
    exit 1
}

echo "▶ Checking code coverage (threshold: ${THRESHOLD}%, report: ${CODECOV_JSON})..."

# Calculate coverage for testable source files only.
# Excluded: UI/ (SwiftUI views), Tests/, .build/, L10n.swift (generated i18n),
#           OwlApp.swift (app entry point with AppKit lifecycle)
COVERAGE=$(jq -r '
    [.data[0].files[]
     | select(.filename | test("/UI/|/Tests/|\\.build/|L10n\\.swift|OwlApp\\.swift|OwlAppExtensions\\.swift") | not)]
    | { covered: (map(.summary.lines.covered) | add),
        total:   (map(.summary.lines.count)   | add) }
    | if .total == 0 then 0
      else (.covered / .total * 100)
      end
' "$CODECOV_JSON")

COVERAGE_INT=$(printf "%.0f" "$COVERAGE")

if [ "$COVERAGE_INT" -lt "$THRESHOLD" ]; then
    echo "✗ Coverage ${COVERAGE_INT}% is below threshold ${THRESHOLD}%"
    echo "  Run: swift test --enable-code-coverage"
    echo "  Then: jq '.data[0].files[] | select(.summary.lines.percent < 80) | {file: .filename, pct: .summary.lines.percent}' $CODECOV_JSON"
    exit 1
fi

echo "✓ Coverage ${COVERAGE_INT}% meets threshold ${THRESHOLD}%"
