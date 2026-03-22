#!/bin/bash
set -e

echo "=== Pre-push: L2 (Integration Tests) + G2 (Security) ==="

# L2: Integration / E2E Tests (EndToEnd suites)
echo "▶ [L2] Running Integration Tests..."
swift test --filter "EndToEnd" 2>&1
echo "✓ [L2] Integration Tests passed"

# G2: Secrets leak detection
echo "▶ [G2] Running gitleaks..."
if command -v gitleaks &> /dev/null; then
    gitleaks detect --source . --no-banner
    echo "✓ [G2] gitleaks passed (no leaks)"
else
    echo "✗ [G2] gitleaks not installed — install: brew install gitleaks"
    exit 1
fi

echo "=== Pre-push passed: L2 ✓ G2 ✓ ==="
