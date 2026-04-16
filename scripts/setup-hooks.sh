#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$(cd "$SCRIPT_DIR/../.git/hooks" 2>/dev/null && pwd)"

if [ -z "$HOOKS_DIR" ]; then
    echo "Error: .git/hooks directory not found"
    exit 1
fi

ln -sf "$SCRIPT_DIR/pre-commit.sh" "$HOOKS_DIR/pre-commit"
ln -sf "$SCRIPT_DIR/pre-push.sh" "$HOOKS_DIR/pre-push"

echo "✓ Git hooks installed"

