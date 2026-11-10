#!/bin/bash
# Unified L1 pre-commit: Git index snapshot (UT, coverage, strict lint, staged secrets).
set -euo pipefail

echo "=== Pre-commit: L1 (index snapshot) ==="

command -v git >/dev/null 2>&1 || {
    echo "pre-commit: git is required" >&2
    exit 1
}

snapshot=
cleanup() {
    status=$?
    trap - EXIT INT TERM HUP
    if [ -n "${snapshot:-}" ]; then
        rm -rf "$snapshot" || :
        snapshot=
    fi
    exit "$status"
}
trap cleanup EXIT
trap "exit 130" INT
trap "exit 143" TERM
trap "exit 129" HUP

echo "▶ [G2a] Running gitleaks (staged)..."
if command -v gitleaks >/dev/null 2>&1; then
    gitleaks protect --staged --no-banner
    echo "✓ [G2a] gitleaks passed"
else
    echo "✗ [G2a] gitleaks not installed — install: brew install gitleaks" >&2
    exit 1
fi

snapshot=$(mktemp -d "${TMPDIR:-/tmp}/owl-index-XXXXXX")
git checkout-index --all --prefix="$snapshot/"
repo=$(git rev-parse --show-toplevel)
script_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}")")" && pwd)"

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
unset GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES

# Share only the Clang module cache with the worktree; never symlink the full .build tree
# (dual module caches break Objective-C bridge builds against IOKit).
module_cache="$repo/.build/owl-precommit-module-cache"
mkdir -p "$module_cache"
export CLANG_MODULE_CACHE_PATH="$module_cache"

export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-}"
if [ -n "${DEVELOPER_DIR:-}" ]; then
    export XCODE_DEFAULT_TOOLCHAIN_OVERRIDE="${XCODE_DEFAULT_TOOLCHAIN_OVERRIDE:-$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain}"
fi

cd "$snapshot"

echo "▶ [L1] Running SwiftLint (strict)..."
if command -v swiftlint >/dev/null 2>&1; then
    swiftlint lint --strict
    echo "✓ [L1] SwiftLint passed"
else
    echo "✗ [L1] SwiftLint not installed — install: brew install swiftlint" >&2
    exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
    echo "✗ [L1] swift is required (macOS 14+ with Swift 6 / Xcode 16+)" >&2
    exit 1
fi

echo "▶ [L1] Running unit tests (excluding EndToEnd)..."
swift test --enable-code-coverage --filter '^(?!.*EndToEnd).*$'
echo "✓ [L1] Unit tests passed"

"$script_dir/check-coverage.sh" 90

echo "=== Pre-commit passed: L1 ✓ G2a ✓ ==="
