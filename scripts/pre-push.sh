#!/bin/bash
set -e

echo "=== Pre-push: L3 (Integration Tests) ==="

# L3: Integration Tests
echo "▶ Running Integration Tests..."
swift test --filter "Integration" 2>&1
echo "✓ Integration Tests passed"

echo "=== Pre-push checks passed ==="
