#!/bin/bash
set -e

echo "=== Pre-commit: L1 (Unit Tests + Coverage) + L2 (SwiftLint) ==="

# L2: SwiftLint
echo "▶ Running SwiftLint..."
if command -v swiftlint &> /dev/null; then
    swiftlint lint --strict
    echo "✓ SwiftLint passed"
else
    echo "⚠ SwiftLint not installed, skipping (brew install swiftlint)"
fi

# L1: Unit Tests with coverage
echo "▶ Running Unit Tests..."
swift test --enable-code-coverage --filter "^(?!.*Integration).*$" 2>&1
echo "✓ Unit Tests passed"

# L1: Coverage gate (≥90% for non-UI code)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/check-coverage.sh" 90

echo "=== Pre-commit checks passed ==="
