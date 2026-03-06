#!/bin/bash
set -e

echo "=== Pre-commit: L1 (Unit Tests) + L2 (SwiftLint) ==="

# L2: SwiftLint
echo "▶ Running SwiftLint..."
if command -v swiftlint &> /dev/null; then
    swiftlint lint --strict
    echo "✓ SwiftLint passed"
else
    echo "⚠ SwiftLint not installed, skipping (brew install swiftlint)"
fi

# L1: Unit Tests
echo "▶ Running Unit Tests..."
swift test --filter "^(?!.*Integration).*$" 2>&1
echo "✓ Unit Tests passed"

echo "=== Pre-commit checks passed ==="
