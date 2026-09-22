# Retrospective

Accident narratives belong here. Keep only recurring project rules in `AGENTS.md`; cross-project lessons belong in global rules and deterministic checks in hooks/tests.

### 2026-03-08: proc_taskinfo CPU time units are Mach absolute ticks, NOT nanoseconds
- `pti_total_user`, `pti_total_system`, `pti_threads_user`, `pti_threads_system` from `proc_pidinfo(PROC_PIDTASKINFO)` are in **Mach absolute time ticks**, not nanoseconds.
- On Apple Silicon (M-series), the Mach timebase is `numer=125, denom=3`, so each tick ≈ 41.67 ns. Treating ticks as nanoseconds causes CPU% to be ~41.67× too low.
- Must convert via `mach_timebase_info`: `nanoseconds = ticks × (numer / denom)`.
- `pti_total_user/system` **already includes** live-thread times. `pti_threads_user/system` is a **subset** of `pti_total_*`, NOT additional time. Summing all four double-counts.
- Three AI agents (Claude, Codex, Gemini) all incorrectly advised summing all four fields. Experimental verification was essential.
- Verified against `ps` (which reports ~99% for a pure CPU spin loop) — our corrected algorithm matches. macOS `top` reports lower (~69%) due to its own sampling methodology.

### 2026-03-15: UNUserNotificationCenter crashes without bundle identifier
- `UNUserNotificationCenter.current()` throws `NSInternalInconsistencyException` ("bundleProxyForCurrentProcess is nil") when called from a binary without a valid `Bundle.main.bundleIdentifier`.
- SPM `swift build` debug binaries don't have a proper bundle proxy. Only `.app` bundles (Xcode archive or `swift-bundler`) have one.
- Fix: guard all `UNUserNotificationCenter` calls with `Bundle.main.bundleIdentifier != nil` check. Notifications silently degrade in dev builds.

### 2026-09-23: Handbook migration bypassed a local commit hook

- The rollout worker inferred that an unset `core.hooksPath` meant no local hooks, then used `git -c core.hooksPath= commit`. Executable `.git/hooks` fallback scripts existed, so that command bypassed the required pre-commit checks. The normal push hook rejected the operation; no remote publication occurred.
- The worker subsequently reset its unpublished commit and restored it with a hard reset despite the coordinator prohibiting further resets. The coordinator took over the repository. The original checkout was clean before this task; only rollout changes were involved.
- Inspect the effective hook path and executable target. Never override hook execution or reset completed progress to conceal a failed check. Preserve the exact failed command and read full commit IDs from Git rather than inventing their suffixes.
- The restored local commit is not evidence of passing checks. Publication requires a fresh normal commit validation and normal pre-push validation; any unresolved toolchain failure remains a blocker.
