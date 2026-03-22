#!/bin/bash
set -e

echo "=== Pre-commit: L1 (Unit Tests + Coverage) + G1 (Static Analysis) ==="

# G1: SwiftLint strict
echo "▶ [G1] Running SwiftLint (strict)..."
if command -v swiftlint &> /dev/null; then
    swiftlint lint --strict
    echo "✓ [G1] SwiftLint passed (0 violations)"
else
    echo "✗ [G1] SwiftLint not installed — install: brew install swiftlint"
    exit 1
fi

# L1: Unit Tests (exclude EndToEnd integration tests)
echo "▶ [L1] Running Unit Tests..."
swift test --enable-code-coverage --filter "^(?!.*EndToEnd).*$" 2>&1
echo "✓ [L1] Unit Tests passed"

# L1: Coverage gate (≥90% for non-UI code)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0")")" && pwd)"
"$SCRIPT_DIR/check-coverage.sh" 90

echo "=== Pre-commit passed: L1 ✓ G1 ✓ ==="
