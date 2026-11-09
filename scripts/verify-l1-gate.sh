#!/bin/bash
# Isolated probes for index-snapshot L1 pre-commit (see hooky/scripts/verify-l1-gate.mjs).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
owned="$(mktemp -d "${TMPDIR:-/tmp}/owl-l1-gate-XXXXXX")"
failed=0

check() {
    local name="$1" ok="$2" detail="${3:-}"
    if [ "$ok" = 1 ]; then
        echo "ok $name${detail:+: ${detail//[$'\t\r\n']/ }}"
    else
        echo "FAIL $name${detail:+: ${detail//[$'\t\r\n']/ }}"
        failed=1
    fi
}

now_ms() {
    python3 -c 'import time; print(int(time.time() * 1000))'
}

snapshot_gone() {
    local scratch="$1"
    [ -d "$scratch" ] || return 0
    ! find "$scratch" -maxdepth 1 -type d -name 'owl-index-*' 2>/dev/null | grep -q .
}

require_tools() {
    local missing=0
    for tool in git npm swift swiftlint gitleaks; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "skip: $tool not available in this environment" >&2
            missing=1
        fi
    done
    return "$missing"
}

run_hook() {
    local dir="$1"
  local scratch
    scratch="$dir/.tmp"
    mkdir -p "$scratch"
    local output status
    output="$(TMPDIR="$scratch" sh "$dir/.husky/pre-commit" 2>&1)" || status=$?
    status="${status:-0}"
    echo "$output"
    return "$status"
}

index_before="$(git -C "$repo" diff --cached --name-only)"

cleanup_owned() {
    rm -rf "$owned"
}

trap cleanup_owned EXIT

if ! require_tools; then
    echo "L1 gate probes skipped (macOS toolchain required)" >&2
    exit 0
fi

# --- Fresh clone + npm install activates Husky ---
clone_dir="$owned/fresh-clone"
git clone -q "$repo" "$clone_dir"
npm install --prefix "$clone_dir" --ignore-scripts >/dev/null 2>&1
npm run prepare --prefix "$clone_dir" >/dev/null 2>&1
hooks_path="$(git -C "$clone_dir" config core.hooksPath)"
check "fresh clone install sets core.hooksPath" "$([ -n "$hooks_path" ] && echo 1 || echo 0)" "$hooks_path"
check "pre-commit hook exists and is executable" "$([ -x "$clone_dir/.husky/pre-commit" ] && echo 1 || echo 0)"

# --- Staged bad SwiftLint, worktree fixed ---
probe_dir="$owned/index-lint"
cp -a "$clone_dir/." "$probe_dir/"
git -C "$probe_dir" config user.email "l1-gate@example.com"
git -C "$probe_dir" config user.name "l1-gate"
target="Sources/OwlCore/Detectors/Comparison.swift"
if [ ! -f "$probe_dir/$target" ]; then
    check "lint probe target present" 0 "missing $target"
else
    original="$(cat "$probe_dir/$target")"
    printf '%s\n// l1-gate: force_unwrapping probe below\nlet _l1GateProbe: String! = nil\n' "$original" >"$probe_dir/$target"
    git -C "$probe_dir" add -- "$target"
    printf '%s' "$original" >"$probe_dir/$target"
    scratch="$probe_dir/.tmp"
    mkdir -p "$scratch"
    set +e
    output="$(TMPDIR="$scratch" sh "$probe_dir/.husky/pre-commit" 2>&1)"
    hook_status=$?
    set -e
    check "staged lint defect rejects commit" "$([ "$hook_status" -ne 0 ] && echo 1 || echo 0)" "$output"
    check "lint probe keeps worktree fix" "$(cmp -s <(printf '%s' "$original") "$probe_dir/$target" && echo 1 || echo 0)"
    check "lint probe keeps staged defect" "$(git -C "$probe_dir" show ":$target" | grep -q '_l1GateProbe' && echo 1 || echo 0)"
    check "lint probe cleans snapshot" "$(snapshot_gone "$scratch" && echo 1 || echo 0)" "$(ls -A "$scratch" 2>/dev/null || true)"
    git -C "$probe_dir" restore --staged "$target" 2>/dev/null || true
    printf '%s' "$original" >"$probe_dir/$target"
fi

# --- Healthy snapshot (full L1, warm .build if present) ---
healthy_dir="$owned/healthy"
cp -a "$clone_dir/." "$healthy_dir/"
git -C "$healthy_dir" config user.email "l1-gate@example.com"
git -C "$healthy_dir" config user.name "l1-gate"
start_ms="$(now_ms)"
scratch="$healthy_dir/.tmp"
mkdir -p "$scratch"
set +e
healthy_out="$(TMPDIR="$scratch" sh "$healthy_dir/.husky/pre-commit" 2>&1)"
healthy_status=$?
set -e
end_ms="$(now_ms)"
elapsed_ms=$((end_ms - start_ms))
check "healthy index snapshot passes" "$([ "$healthy_status" -eq 0 ] && echo 1 || echo 0)" "${healthy_out:0:240}"
if [ "${CI:-}" = "true" ]; then
    check "healthy L1 timing recorded (CI)" 1 "${elapsed_ms}ms — local warm target is <30s"
else
    check "healthy run under 30s (warm cache)" "$([ "$elapsed_ms" -lt 30000 ] && echo 1 || echo 0)" "${elapsed_ms}ms"
fi
echo "timing healthy L1 gate: ${elapsed_ms}ms"

index_after="$(git -C "$repo" diff --cached --name-only)"
check "repository index untouched" "$([ "$index_before" = "$index_after" ] && echo 1 || echo 0)"

if [ "$failed" -ne 0 ]; then
    exit "$failed"
fi
echo "L1 gate probes passed"
