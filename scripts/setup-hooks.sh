#!/bin/bash
set -e

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v npm >/dev/null 2>&1; then
    echo "Error: npm is required to install Husky hooks (Node.js LTS)." >&2
    exit 1
fi

(cd "$repo_root" && npm install && npm run prepare)
echo "✓ Husky Git hooks installed (core.hooksPath → .husky)"
